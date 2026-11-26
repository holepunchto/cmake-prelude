#include "fixture.h"

VISIBLE int
app(void) {
  return 4;
}

VISIBLE int
app_unlisted(void) {
  return 5;
}

int
main(void) {
  void *executable = fixture_open(NULL);
  if (executable == NULL) return 1;

  if (!fixture_exports(executable, "app")) return 2;
  if (!fixture_exports(executable, "dep")) return 3;
  if (fixture_exports(executable, "app_unlisted")) return 4;

  return 0;
}
