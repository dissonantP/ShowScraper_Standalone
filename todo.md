OUTPUT:

WARNING: GoldenBull produced 0 events!
WARNING: Knockout produced 0 events!
WARNING: Zeitgeist produced 0 events!
WARNING: Yoshis produced 0 events!
WARNING: ManuallyAdded produced 0 events!
WARNING: BandcampOakland produced 0 events!
ERROR: SfJazz failed to scrape. Skipped.
ERROR: Paramount failed to scrape. Skipped.

TODOS:
- [x] Disable GoldenBull
- [x] Dont give any Warning if the following have no events:
  - Zeitgeist
  - BandcampOakland
  - ManuallyAdded
- Fix the following:
  - [x] Knockout
  - [x] Yoshis
  - [x] SF Jazz
  - [x] Paramount

You can use the Playwright MCP to find the correct selectors / logic, and then translate it into Selenium.
Note that it is possible that we have IP related issues, if you see no events on those venues which I requested
to fix. If that seems to be the case (no events can be found), let me know and I can investigate manually.
