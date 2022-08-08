@echo off
REM The following batch file takes an encrypted PFX file and convert it to a x509 Java certificate file

REM After getting the x.509 Java certificate, use the following command to import into the Java keystore in each Nuix workstation.
REM 
REM "C:\Program Files\Nuix\Nuix 7.4\jre\bin\keytool" -import -alias nycnmsdev01 -storepass changeit -keystore "C:\Program Files\Nuix\Nuix 7.4\jre\lib\security\cacerts" -file nycnmsdev01.ameclientsdev.sfdev.local.x509.cer

REM Login to the the License Server site (e.g. https://nycnmsdev01.ameclientsdev.sfdev.local:27443/)  and select Admin actions > 
REM Configuration > SSL Certificate
REM Upload the *.pem for the Certificate file
REM Upload the *.decrypted.key for the Private key file

:START
set CONFIGINI=pkcs12topem.ini
set BINDIR=%~dp0

REM Initializes configuration
if not exist %CONFIGINI% @echo %CONFIGINI% not found. Exiting.&&goto :HALT
call :LOADCONFIG %CONFIGINI%

REM Overwrite CONFIG from INI settings here
REM set PASSWORD=
REM set PASSPHRASE=

REM Loop through all certs
for /f "eol=#" %%a in ('dir input\*.pfx /b') do (
	call :PROCESS input "%%a" "%PASSWORD%" "%PASSPHRASE%"
)
echo Done!
goto :END

:PROCESS
REM Store certificate full file path
set CERTFILE=%~f1\%~2
set PASSWD="%~3"
set PASSPH="%~4"
set PREFIX=%~n2
set OUTDIR=output
echo *****
echo *** Processing %CERTFILE% ***
echo *****

REM Create output directory
echo Creating output directory %OUTDIR%
if not exist "%OUTDIR%" mkdir "%OUTDIR%"

REM Create key .pem file
echo Create key .pem file
REM bin\openssl pkcs12 -in "%CERTFILE%" -nocerts -password pass:%PASSWD% -passout pass:%PASSPH% | bin\sed -ne "/-BEGIN ENCRYPTED PRIVATE KEY-/,/-END ENCRYPTED PRIVATE KEY-/p" > "%OUTDIR%\%PREFIX%.key"
bin\openssl pkcs12 -in "%CERTFILE%" -nocerts -password pass:%PASSWD% -passout pass:%PASSPH% | bin\sed -ne "/-BEGIN ENCRYPTED PRIVATE KEY-/,/-END ENCRYPTED PRIVATE KEY-/p" > "%OUTDIR%\%PREFIX%.key"
if errorlevel 0 echo Created "%OUTDIR%\%PREFIX%.key"

REM Create certificate .pem file
echo Create certificate .pem file
bin\openssl pkcs12 -in "%CERTFILE%" -nokeys -password pass:%PASSWD% -passout pass:%PASSPH% | bin\sed -ne "/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p" > "%OUTDIR%\%PREFIX%.pem"
bin\openssl pkcs12 -in "%CERTFILE%" -nokeys -password pass:%PASSWD% | bin\sed -ne "/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p" > "%OUTDIR%\%PREFIX%.pem"
if errorlevel 0 echo Created "%OUTDIR%\%PREFIX%.pem"

REM Create not secure certificate .pem file 
echo Create certificate .pem file
rem bin\openssl pkcs12 -in "%CERTFILE%" -nokeys -password pass:%PASSWD% | bin\sed -ne "/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p" > "%OUTDIR%\%PREFIX%.notsecure.pem"
bin\openssl pkcs12 -in "%CERTFILE%" -nokeys -password pass:%PASSWD% > "%OUTDIR%\%PREFIX%.notsecure.pem"
if errorlevel 0 echo Created "%OUTDIR%\%PREFIX%.notsecure.pem"

REM Decrypt key file
echo Decrypting key file
bin\openssl rsa -in "%OUTDIR%\%PREFIX%.key" -out "%OUTDIR%\%PREFIX%.decrypted.key" -passin pass:%PASSWD%
if errorlevel 0 echo Decrypted key is "%OUTDIR%\%PREFIX%.decrypted.key"

REM Convert to  Java Certificate
echo Converting to Java x509 format
bin\openssl x509 -inform pem -in "%OUTDIR%\%PREFIX%.pem" -outform der -out "%OUTDIR%\%PREFIX%.x509.cer"
if errorlevel 0 echo  Java x509 certificate is "%OUTDIR%\%PREFIX%.x509.cer"

REM Convert 
echo Converting for SSLProxyMachineCertificateFile 
bin\openssl pkcs12 -in "%CERTFILE%" -out "%OUTDIR%\cert.key" -nocerts -nodes -password pass:%PASSWD% -passout pass:%PASSPH%"
bin\openssl rsa -in "%OUTDIR%\cert.key" -out "%OUTDIR%\client.key"
bin\openssl pkcs12 -in "%CERTFILE%" -password pass:%PASSWD% -out "%OUTDIR%\client.pem" -clcerts -nokeys
bin\cat "%OUTDIR%\client.key" >> "%OUTDIR%\client.pem"
goto :EOF

:LOADCONFIG
REM Loads build settings from specified INI file
for /f "eol=# delims=" %%x in (%1) do (
	set "%%x"
)
goto :EOF

:USAGE
echo.
echo %0 configuration
echo.
echo where configuration identifies the INI file you are loading.
goto :HALT

:HALT
cd %OLDDIR%
call :__SetErrorLevel
call :__ErrorExit 2> nul
goto :EOF

:__ErrorExit
()
goto :EOF

:__SetErrorLevel
exit /b %RETVAL%
goto :EOF

:END
exit /b %RETVAL%