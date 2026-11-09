import { test, expect, type Page } from "@playwright/test";
import { bangkokProvince, inputFor, place, reportFixture } from "../tests/fixtures/lifeReport";
import { lifeCopy } from "../src/lib/lifeReport";

const handan = {
  id: "geonames:1808963", countryCode: "CN", nameEnglish: "Handan", nameChinese: "邯郸市", nameThai: "Handan",
  labelChinese: "中国，河北省，邯郸市", labelThai: "จีน，มณฑลเหอเป่ย์，Handan",
  timeZone: "Asia/Shanghai", latitude: 36.60999, longitude: 114.48764,
  provinceId: "geonames:1808773", provinceNameEnglish: "Hebei", provinceNameChinese: "河北省", provinceNameThai: "มณฑลเหอเป่ย์",
};
const hebei = { ...handan, id: handan.provinceId, nameEnglish: "Hebei", nameChinese: "河北省", nameThai: "มณฑลเหอเป่ย์", aliases: ["河北", "Hebei"] };

async function locations(page: Page, ambiguous = false) {
  await page.route("**/api/thai-locations?*", route => {
    const url = new URL(route.request().url());
    const country = url.searchParams.get("country");
    if (url.searchParams.get("level") === "province") return route.fulfill({ json: { items: country === "CN" ? [hebei] : [bangkokProvince], total: 1 } });
    const row = country === "CN" ? handan : place;
    expect(url.searchParams.get("level")).toBe("locality");
    expect(url.searchParams.get("province")).toBe(country === "CN" ? hebei.id : bangkokProvince.id);
    const items = ambiguous ? [row, { ...row, id: "geonames:12153237", labelChinese: "中国，河北省，另一处同名地点" }] : [row];
    return route.fulfill({ json: { items, total: items.length, resolved: null } });
  });
}

test("all three arrows provide cascading choices and changing country clears descendants", async ({ page }) => {
  await locations(page);
  await page.goto("?lang=zh");
  await expect(page.locator('label[for="birth-date"]')).toHaveText("☉出生日期阳历");
  await expect(page.locator("#birth-province")).toBeDisabled();
  await expect(page.locator("#birth-city")).toBeDisabled();
  await page.getByRole("button", { name: "选择出生国家", exact: true }).click();
  await expect(page.getByRole("option")).toHaveCount(2);
  await page.getByRole("option", { name: /中国/ }).click();
  await page.getByRole("button", { name: "选择省份 / 府州", exact: true }).click();
  await page.locator(`[data-region-id="${hebei.id}"]`).click();
  await page.getByRole("button", { name: "选择市区", exact: true }).click();
  await page.locator(`[data-place-id="${handan.id}"]`).click();
  await expect(page.locator("#birth-province")).toHaveValue("河北省");
  await expect(page.locator("#birth-city")).toHaveValue("邯郸市");
  await expect(page.getByTestId("detected-birthplace")).toContainText("中国，河北省，邯郸市");
  await page.getByRole("button", { name: "选择出生国家", exact: true }).click();
  await page.getByRole("option", { name: /泰国/ }).click();
  await expect(page.locator("#birth-province")).toHaveValue("");
  await expect(page.locator("#birth-city")).toHaveValue("");
  await expect(page.locator("#birth-city")).toBeDisabled();
  await expect(page.getByTestId("detected-birthplace")).toHaveCount(0);
  await page.getByRole("button", { name: "选择省份 / 府州", exact: true }).click();
  await expect(page.getByRole("option")).toContainText("曼谷");
  await expect(page.locator(`[data-region-id="${hebei.id}"]`)).toHaveCount(0);
});

test("typed country and province aliases support city search and localized restoration at 320px", async ({ page }) => {
  await locations(page);
  await page.setViewportSize({ width: 320, height: 850 });
  await page.goto("?lang=zh");
  await page.locator("#birth-country").fill("China");
  await page.locator("#birth-province").fill("河北");
  await page.locator("#birth-city").fill("邯郸市");
  await page.locator(`[data-place-id="${handan.id}"]`).click();
  await expect(page.getByRole("listbox")).toHaveCount(0);
  await page.locator('[data-lang="th"]').click();
  await expect(page.getByTestId("detected-birthplace")).toContainText("จีน，มณฑลเหอเป่ย์，Handan");
  await expect(page.locator("#birth-country")).toHaveValue("จีน");
  await expect(page.locator("#birth-province")).toHaveValue("มณฑลเหอเป่ย์");
  const provinceBox = await page.locator("#birth-province").boundingBox();
  const cityBox = await page.locator("#birth-city").boundingBox();
  expect(provinceBox!.y).toBe(cityBox!.y);
  expect(provinceBox!.x + provinceBox!.width).toBeLessThan(cityBox!.x);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
});

test("ambiguous places require confirmation and can be selected with the keyboard", async ({ page }) => {
  await locations(page, true);
  await page.goto("?lang=zh");
  await page.locator("#birth-country").fill("中国");
  await page.locator("#birth-province").fill("河北省");
  await page.locator("#birth-city").fill("邯郸");
  await expect(page.getByRole("option")).toHaveCount(2);
  await expect(page.getByTestId("detected-birthplace")).toHaveCount(0);
  await page.locator("#birth-city").press("Enter");
  await expect(page.getByTestId("detected-birthplace")).toContainText(handan.labelChinese);
  await expect(page.getByRole("listbox")).toHaveCount(0);
  await page.locator("#birth-city").fill("其他地点");
  await expect(page.getByTestId("detected-birthplace")).toHaveCount(0);
});

test("opening an older report in another province uses its saved location on the report page", async ({ page }) => {
  const sichuan = { ...hebei, id: "geonames:1794299", nameEnglish: "Sichuan", nameChinese: "四川省", nameThai: "มณฑลเสฉวน", aliases: ["四川"] };
  const chengdu = { ...handan, id: "geonames:1815286", nameEnglish: "Chengdu", nameChinese: "成都市", nameThai: "เฉิงตู", labelChinese: "中国，四川省，成都市", provinceId: sichuan.id, provinceNameEnglish: "Sichuan", provinceNameChinese: "四川省", provinceNameThai: "มณฑลเสฉวน" };
  const original = inputFor();
  const saved = reportFixture({ ...original, profile: { ...original.profile, birthplace: "Chengdu, CN", country_code: "CN", timezone: "Asia/Shanghai", location_id: chengdu.id } });
  // Old saved snapshots have no province metadata and are enriched from their existing ID.
  saved.location = { id: chengdu.id, nameEnglish: chengdu.nameEnglish, nameChinese: chengdu.nameChinese, timeZone: "Asia/Shanghai" };
  await page.route("**/api/life-reports**", route => route.fulfill({ json: new URL(route.request().url()).pathname === "/api/life-reports" ? { items: [saved] } : saved }));
  await page.route("**/api/thai-locations?*", route => {
    const params = new URL(route.request().url()).searchParams;
    if (params.get("level") === "province") return route.fulfill({ json: { items: [hebei, sichuan], total: 2 } });
    if (params.get("level") === "detail") return route.fulfill({ json: { items: [chengdu], total: 1, resolved: chengdu } });
    const offset = Number(params.get("offset"));
    if (params.get("province") === sichuan.id) {
      return route.fulfill({ json: { items: [chengdu], total: 1, resolved: null } });
    }
    const items = Array.from({ length: offset ? 1 : 100 }, (_, i) => ({ ...handan, id: `geonames:${500000 + offset + i}`, labelChinese: `中国，河北省，河北测试地点${offset + i}` }));
    return route.fulfill({ json: { items, total: 101, resolved: null } });
  });
  await page.goto("?lang=zh");
  await page.locator("#birth-country").fill("中国");
  await page.locator("#birth-province").fill("河北省");
  await page.getByRole("button", { name: "选择市区", exact: true }).click();
  await expect(page.getByRole("option")).toHaveCount(100);
  await page.locator("#birth-city").focus();
  for (let i = 0; i < 12; i++) await page.locator("#birth-city").press("ArrowDown");
  const active = page.getByRole("option", { selected: true });
  const activeBox = await active.boundingBox(), listBox = await page.getByRole("listbox").boundingBox();
  expect(activeBox!.y).toBeGreaterThanOrEqual(listBox!.y);
  expect(activeBox!.y + activeBox!.height).toBeLessThanOrEqual(listBox!.y + listBox!.height);
  await page.getByRole("button", { name: "查看更多地点", exact: true }).click();
  await expect(page.getByRole("option")).toHaveCount(101);
  await page.getByRole("button", { name: lifeCopy.zh.history, exact: true }).click();
  await page.getByRole("dialog").getByRole("button").filter({ hasText: lifeCopy.zh.open }).click();
  await expect(page).toHaveURL(/report\.html/);
  await expect(page.locator(".life-report-cover")).toContainText("Chengdu, CN");
  await expect(page.locator(".life-report-cover")).toContainText("Asia/Shanghai");
  await expect(page.locator("#birth-form")).toHaveCount(0);
});
