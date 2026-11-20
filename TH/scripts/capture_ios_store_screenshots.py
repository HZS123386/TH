"""Capture the Thai review edition on two native iOS simulators."""

import json
import os
from pathlib import Path
import plistlib
import struct
import subprocess
from tempfile import TemporaryDirectory
import time
from zipfile import ZIP_DEFLATED, ZipFile


BUNDLE_ID = "app.fate.fateApp"
SAMPLE_BIRTH = {
    "birth_date": "1990-01-01",
    "birth_time": "12:00",
    "tzid": "Asia/Bangkok",
    "birthplace": "กรุงเทพมหานคร",
    "place_id": "geonames:1609350",
    "country_code": "TH",
    "latitude": 13.75,
    "longitude": 100.5,
}


def simctl(*arguments):
    return subprocess.check_output(["xcrun", "simctl", *arguments], text=True).strip()


def create_simulator(names, label):
    device_types = json.loads(simctl("list", "devicetypes", "--json"))["devicetypes"]
    runtimes = json.loads(simctl("list", "runtimes", "--json"))["runtimes"]
    available = [item for item in runtimes if item["isAvailable"] and item["name"].startswith("iOS ")]
    available.sort(key=lambda item: tuple(map(int, item["version"].split("."))), reverse=True)
    for name in names:
        for item in device_types:
            if item["name"] != name:
                continue
            for runtime in available:
                try:
                    udid = simctl("create", f"FATE Store {label}", item["identifier"], runtime["identifier"])
                except subprocess.CalledProcessError:
                    continue
                print(f"{label}: {name} on {runtime['name']}", flush=True)
                return udid
    raise RuntimeError(f"No available simulator for {label}: {', '.join(names)}")


def png_details(path):
    with path.open("rb") as source:
        header = source.read(26)
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path.name} is not a PNG file")
    width, height, _, color_type = struct.unpack(">IIBB", header[16:26])
    return (width, height), color_type


def capture(app, output, names, label, allowed_sizes):
    udid = create_simulator(names, label)
    profile = json.dumps(SAMPLE_BIRTH, ensure_ascii=False)
    try:
        print(simctl("bootstatus", udid, "-b"), flush=True)
        simctl("install", udid, str(app))
        data = Path(simctl("get_app_container", udid, BUNDLE_ID, "data"))
        preferences = data / "Library" / "Preferences" / f"{BUNDLE_ID}.plist"
        preferences.parent.mkdir(parents=True, exist_ok=True)
        prior = plistlib.loads(preferences.read_bytes()) if preferences.exists() else {}
        prior.update({"flutter.fate.locale": "th", "flutter.fate.birth.guest": profile})
        preferences.write_bytes(plistlib.dumps(prior, fmt=plistlib.FMT_BINARY))
        simctl("status_bar", udid, "override", "--time", "9:41", "--dataNetwork", "wifi",
               "--wifiMode", "active", "--wifiBars", "3", "--cellularMode", "active",
               "--cellularBars", "4", "--batteryState", "unplugged", "--batteryLevel", "100")
        print(simctl("launch", udid, BUNDLE_ID, "--disable-vm-service-publication",
                     "-flutter.fate.locale", "th", "-flutter.fate.birth.guest", profile), flush=True)
        time.sleep(16)
        with TemporaryDirectory(prefix="fate-simulator-") as temporary:
            raw = Path(temporary) / "raw.png"
            simctl("io", udid, "screenshot", "--type=png", str(raw))
            size, color_type = png_details(raw)
            if size not in allowed_sizes:
                raise RuntimeError(f"Unexpected {label} dimensions: {size}")
            filename = output / f"FATE-th-{label}-{size[0]}x{size[1]}.png"
            if color_type in (4, 6):
                bmp = Path(temporary) / "opaque.bmp"
                subprocess.run(["sips", "-s", "format", "bmp", str(raw), "--out", str(bmp)], check=True)
                subprocess.run(["sips", "-s", "format", "png", str(bmp), "--out", str(filename)], check=True)
            else:
                filename.write_bytes(raw.read_bytes())
            final_size, final_type = png_details(filename)
            if final_size != size or final_type not in (0, 2, 3):
                raise RuntimeError(f"{filename.name} must retain its size and have no alpha channel")
            print(f"Captured {filename.name}", flush=True)
            return filename
    finally:
        subprocess.run(["xcrun", "simctl", "shutdown", udid], check=False)


def main():
    app = Path("build/ios/iphonesimulator/Runner.app").resolve(strict=True)
    output = Path(os.environ["CM_BUILD_DIR"]) / "TH/output/ios-submission/store-screenshots"
    output.mkdir(parents=True, exist_ok=True)
    iphone = capture(app, output, ("iPhone 17 Pro", "iPhone 16 Pro", "iPhone 15 Pro"),
                     "iPhone-Medium", {(1179, 2556), (1206, 2622)})
    ipad = capture(app, output, ("iPad Pro 13-inch (M5)", "iPad Pro 13-inch (M4)",
                                 "iPad Pro (13-inch) (M4)", "iPad Pro (12.9-inch) (6th generation)"),
                   "iPad-13", {(2064, 2752), (2048, 2732)})
    with ZipFile(output / "FATE-AppStore-Thai-Screenshots.zip", "w", ZIP_DEFLATED) as archive:
        for image in (iphone, ipad):
            archive.write(image, image.name)


if __name__ == "__main__":
    main()
