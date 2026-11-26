#ifndef FIXTURE_H
#define FIXTURE_H

#include <stdbool.h>
#include <stddef.h>

#ifdef _WIN32
#include <windows.h>

#define VISIBLE

static void *
fixture_open(const char *path) {
  return path ? (void *) LoadLibraryA(path) : (void *) GetModuleHandleA(NULL);
}

static bool
fixture_exports(void *handle, const char *symbol) {
  return GetProcAddress((HMODULE) handle, symbol) != NULL;
}
#else
#include <dlfcn.h>

#define VISIBLE __attribute__((visibility("default")))

static void *
fixture_open(const char *path) {
  return dlopen(path, RTLD_NOW | RTLD_LOCAL);
}

static bool
fixture_exports(void *handle, const char *symbol) {
  return dlsym(handle, symbol) != NULL;
}
#endif

#endif
