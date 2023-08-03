# How to compile and test fut

`fut` is implemented in Fusion.
To solve the egg-and-chicken problem, its transpilations to C++, C#
and JavaScript are included with the source code.

## Building a C++ fut

You need a C++20 compiler, such as GCC 13 or Clang 16.
Build with:

    make

## Building a C# fut

You need [.NET 7.0 or 6.0 SDK](https://dotnet.microsoft.com/en-us/download).
On Windows, it is included in Visual Studio 2022.
Build with:

    make FUT_HOST=cs

## Building a Node.js fut

You need [Node.js](nodejs.org).
Build with:

    make FUT_HOST=node

## Testing

To run `fut` tests, you will need:
* GNU Make
* perl
* GNU diff
* C and C++ compilers
* [Java compiler](https://www.oracle.com/java/technologies/downloads/)
* [Node.js](https://nodejs.org/)
* Python
* [Swift](https://swift.org/)
* [GLib](https://wiki.gnome.org/Projects/GLib)

To get GNU Make, perl, GNU diff, Clang, Python and GLib on Windows,
install [MSYS2](https://www.msys2.org/), start "MSYS2 MinGW 64-bit"
and add packages with:

    pacman -S make perl diffutils mingw-w64-x86_64-gcc mingw-w64-x86_64-python mingw-w64-x86_64-glib2

On macOS:

    brew install node glib pkg-config

Run the tests with:

    make test

The `-jN` option is supported and strongly recommended.
