#include "fixture.h"

int
main(void) {
  void *executable = fixture_open(NULL);
  if (executable == NULL) return 1;

  if (!fixture_exports(executable, "foo")) return 2;
  if (fixture_exports(executable, "foo_unlisted")) return 3;

  return 0;
}
