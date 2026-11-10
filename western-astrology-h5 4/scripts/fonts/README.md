These are build inputs for the existing Noto font assets, licensed under SIL OFL.

`location-characters.txt` contains only the unique characters in public Chinese
place names from the project's GeoNames location index, SHA-256
`c11630844c8361832ee4882ef39d37d5aa2ead66863d3dc4223cf251f9a83cb4`.
It contains no user data. GB2312 characters and all fixed UI copy are also included
when generating the additional font. Remaining characters load from the original
full font on demand.

Install the build tool from `scripts/font-requirements.txt`, then run
`python scripts/prepare-fonts.py` after preparing translations. The generated OTF,
TTF and Dart coverage files are committed, so normal builds do not need Python or
fontTools. Original font outlines and licenses are retained; derived families use
the `Fate` name. Original source fonts remain available for regeneration.
