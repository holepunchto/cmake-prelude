#include "fixture.h"

int
main(int argc, char **argv) {
  void *library = fixture_open(argv[1]);
  if (library == NULL) return 1;

  if (!fixture_exports(library, "foo")) return 2;
  if (!fixture_exports(library, "dep")) return 3;
  if (fixture_exports(library, "foo_unlisted")) return 4;

  return 0;
}
