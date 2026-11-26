#include "fixture.h"

VISIBLE int
foo(void) {
  return 1;
}

VISIBLE int
foo_unlisted(void) {
  return 2;
}
