@echo off

rem change active code page for utf-8
chcp 65001 >NUL

rem set console color
color 0F

set GNU_MIRROR=https://ftpmirror.gnu.org

set GCC_VERSION=13.2.0
set GCC_ARCHIVE=gcc-%GCC_VERSION%.tar.gz
set GCC_URL=%GNU_MIRROR%/gcc/gcc-%GCC_VERSION%/%GCC_ARCHIVE%

set BINUTILS_VERSION=2.42
set BINUTILS_ARCHIVE=binutils-%BINUTILS_VERSION%.tar.gz
set BINUTILS_URL=%GNU_MIRROR%/binutils/%BINUTILS_ARCHIVE%

set CPC_ROOT=%~dp0
set CPC_POSIX_ROOT=%CPC_ROOT:\=/%
set CPC_TOOLS=%CPC_ROOT%tools
set CPC_POSIX_TOOLS=%CPC_POSIX_ROOT%tools

rem overwrite PATH in order to avoid conflict
set PATH=%CPC_TOOLS%\bin;C:\WINDOWS\system32;C:\WINDOWS;C:\WINDOWS\System32\Wbem;C:\WINDOWS\System32\WindowsPowerShell\v1.0\
set MSYS2_PATH_TYPE=inherit

set CPC_ARCH=riscv64
set CPC_TRIPLET=%CPC_ARCH%-unknown-elf

mkdir %CPC_TOOLS% >NUL 2>NUL

if "%MSYSPATH%"=="" (
    set MSYSPATH=C:\msys64
)

set MSYSTEM=UCRT64
set BASH=%MSYSPATH%\usr\bin\bash.exe
set POSIXRUN=%BASH% -l -c

set __PRG_NAME=%~nx0

rem Check if MSYS2 is installed
if exist %BASH% goto :main

echo Please install msys2 to "%MSYSPATH%"
echo. (https://www.msys2.org/)
exit /b

rem ==================================================================
rem Download file
:dl_tool
	bitsadmin.exe /transfer "DL %~2" %~1 %CPC_TOOLS%\%~2
	exit /b

rem ==================================================================
rem check gcc toolchain is present
:check_gcc
	echo|set /p dummy=Check if %CPC_TRIPLET%-gcc is present...
	%POSIXRUN% "which %CPC_TRIPLET%-gcc 2>/dev/null"
	if not %ERRORLEVEL%==0 (
	   echo NOT FOUND
	   goto :build_gcc
	)
	exit /b

:build_gcc
	rem posix shell cmd to build gcc
	set buildcmd=cd %CPC_POSIX_TOOLS%/gcc-%GCC_VERSION%; ^
mkdir -p cpcbuild; cd cpcbuild; ^
../configure --target=\"%CPC_TRIPLET%\" --prefix=\"%CPC_POSIX_TOOLS%\" --with-sysroot --disable-nls --enable-languages=c --with-newlib; ^
make all-gcc; ^
make all-target-libgcc; ^
make install-gcc; ^
make install-target-libgcc

	rem end
	if not exist %CPC_TOOLS%\%GCC_ARCHIVE% (
	   call :dl_tool %GCC_URL% %GCC_ARCHIVE%
	)
	echo Uncompress %GCC_ARCHIVE%
	%POSIXRUN% "cd %CPC_POSIX_TOOLS%; tar -xf %GCC_ARCHIVE%"
	%POSIXRUN% "%buildcmd%"

	exit /b

rem ==================================================================
rem build binutils if needed
:check_binutils
	echo|set /p dummy=Check if %CPC_TRIPLET%-as is present...
	%POSIXRUN% "which %CPC_TRIPLET%-as 2>/dev/null"
	if not %ERRORLEVEL%==0 (
	   echo NOT FOUND
	   goto :build_binutils
	)
	exit /b

:build_binutils
	rem posix shell cmd to build binutils
	set buildcmd=cd %CPC_POSIX_TOOLS%/binutils-%BINUTILS_VERSION%; ^
mkdir -p cpcbuild; cd cpcbuild; ^
../configure --target=\"%CPC_TRIPLET%\" --prefix=\"%CPC_POSIX_TOOLS%\"  --with-sysroot --disable-nls --disable-werror; ^
make; make install


        rem end
	if not exist %CPC_TOOLS%\%BINUTILS_ARCHIVE% (
	   call :dl_tool %BINUTILS_URL% %BINUTILS_ARCHIVE%
	)
	echo Uncompress %BINUTILS_ARCHIVE%
	%POSIXRUN% "cd %CPC_POSIX_TOOLS%; tar -xf %BINUTILS_ARCHIVE%"
	%POSIXRUN% "%buildcmd%"

	exit /b

rem ==================================================================
rem ensure msys has prerequisites
:msys_prereq
set builddeps=pacman --needed --noconfirm -S ^
mingw-w64-ucrt-x86_64-toolchain ^
mingw-w64-ucrt-x86_64-autotools ^
mingw-w64-ucrt-x86_64-binutils ^
mingw-w64-ucrt-x86_64-crt ^
mingw-w64-ucrt-x86_64-gcc ^
mingw-w64-ucrt-x86_64-gcc-ada ^
mingw-w64-ucrt-x86_64-gmp ^
mingw-w64-ucrt-x86_64-gperf ^
mingw-w64-ucrt-x86_64-headers ^
mingw-w64-ucrt-x86_64-isl ^
mingw-w64-ucrt-x86_64-libiconv ^
mingw-w64-ucrt-x86_64-mpc ^
mingw-w64-ucrt-x86_64-mpfr ^
mingw-w64-ucrt-x86_64-windows-default-manifest ^
mingw-w64-ucrt-x86_64-winpthreads ^
mingw-w64-ucrt-x86_64-zlib ^
mingw-w64-ucrt-x86_64-zstd

	rem
	%POSIXRUN% "%builddeps%"
	exit /b

rem ==================================================================
rem Print usage and exit
:usage
	echo USAGE: %__PRG_NAME% [OPTIONS]...
	echo Build helper for CpcdosOS3
	echo.
	echo.    /?, --help   display this menu and exit
	exit /b

rem ==================================================================
rem script entry point
:main
	set PATH=%PATH%;%MSYSPATH%\usr\bin
:loop
	if "%~1"=="" goto :end
	if /i "%~1"=="/?" call :usage & goto :eof
	if /i "%~1"=="-h" call :usage & goto :eof
	if /i "%~1"=="--help" call :usage & goto :eof
	shift
	goto :loop
:end
	call :msys_prereq
	call :check_binutils
	call :check_gcc
