#ifndef FOO_H
#define FOO_H

#ifdef _WIN32
#define FOO_EXTERN
#else
#define FOO_EXTERN __attribute__((visibility("default")))
#endif

FOO_EXTERN int
foo(void);

#endif
