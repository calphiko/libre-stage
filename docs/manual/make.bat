@ECHO OFF
pushd %~dp0
if "%SPHINXBUILD%" == "" (set SPHINXBUILD=sphinx-build)
set SOURCEDIR=.
set BUILDDIR=_build
if "%1" == "" goto help
if "%1" == "html-de" (
	%SPHINXBUILD% -b html -D language=de %SOURCEDIR% %BUILDDIR%/html/de
	goto end
)
if "%1" == "html-en" (
	%SPHINXBUILD% -b html -D language=en %SOURCEDIR% %BUILDDIR%/html/en
	goto end
)
%SPHINXBUILD% -M %1 %SOURCEDIR% %BUILDDIR% %SPHINXOPTS% %O%
goto end
:help
%SPHINXBUILD% -M help %SOURCEDIR% %BUILDDIR% %SPHINXOPTS% %O%
:end
popd

