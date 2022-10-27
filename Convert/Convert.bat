@echo off 

SETLOCAL

set file=%1

:: SETUP FOLDERS
if not exist logs mkdir logs
if not exist olds mkdir olds

:: GET FILEPATHS AND TIMESTAMP 
FOR %%i IN (%file%) DO (
  SET filedrive=%%~di
  SET filepath=%%~pi
  SET filename=%%~ni
  SET fileextension=%%~xi
)

:: Check additional parameters
set DODELETETMP=0
:loop
  if ["%~1"]==[""] (goto loopend)
  if ["%~1"]==["deletetmp"] (
    set DODELETETMP="deletetmp"
  )
  shift
  goto loop
:loopend

set hour=%time:~0,2%
if "%hour:~0,1%" == " " set hour=0%hour:~1,1%
set min=%time:~3,2%
if "%min:~0,1%" == " " set min=0%min:~1,1%
set secs=%time:~6,2%
if "%secs:~0,1%" == " " set secs=0%secs:~1,1%

set DELIMITER=-

set DATESTRING=%date:~-4,4%%DELIMITER%%date:~-7,2%%DELIMITER%%date:~-10,2%
set TIMESTRING=%hour%%DELIMITER%%min%%DELIMITER%%secs%
set TimeStamp=%DATESTRING%_%TIMESTRING%

:: SETUP DB FILE AND PATH
set db_file_path=%filedrive%%filepath%
set db_file_name=%filename%%fileextension%

:: CHECK FOR INPUT DATABASE FILE
if not exist "%db_file_path%%db_file_name%" goto :error

:: SETUP VARIABLES NEEDED
set TimeStampLogFileFB25x=%TimeStamp%_FB25x_%db_file_name%.log
set TimeStampLogFileFB40x=%TimeStamp%_FB40x_%db_file_name%.log
set ISC_USER=sysdba
set ISC_PASSWORD=masterkey
set old_db_backup_file_name=%TimeStamp%_%db_file_name%

:: PROCESS FILE ON THE COPY OF FILE
move /y "%db_file_path%%db_file_name%" "%db_file_path%%db_file_name%.tmp"
if %ERRORLEVEL% NEQ 0 (
	SET ERROR_MSG=Could not move the db-file as a temp

	@echo on
	@echo %ERROR_MSG% 
	@echo "%ERROR_MSG%" >> "logs/"%TimeStampLogFileFB40x%
	@echo off

	goto :error
)

:: DO BACKUP AND RESTORE
"25/gbak" -z -b -g -v -st t -y "logs/"%TimeStampLogFileFB25x% "%db_file_path%%db_file_name%.tmp" stdout|^
"40/gbak" -z -c -v -page_size 32768 -st t -y "logs/"%TimeStampLogFileFB40x% stdin "%db_file_path%%db_file_name%"
if %ERRORLEVEL% NEQ 0 (
	SET ERROR_MSG=ERROR: Conversion failed while backup/restore

	@echo on
	@echo %ERROR_MSG% 
	@echo "%ERROR_MSG%" >> "logs/"%TimeStampLogFileFB40x%
	@echo off

	goto :error
) else (

	@echo on
	@echo         SUCCESS: Database succesfully converted to FB40x: %db_file_path%%db_file_name%
	@echo off
)

:: DELETE TMP-FILE, SKIPPING COPY TO OLDS
if %DODELETETMP%=="deletetmp" (
	del "%db_file_path%%db_file_name%.tmp"
	if %ERRORLEVEL% NEQ 0 (
		SET ERROR_MSG=Could not delete the temp db-file

		@echo on
		@echo %ERROR_MSG% 
		@echo "%ERROR_MSG%" >> "logs/"%TimeStamp%-BatchFileError.log
		@echo off

		goto :error
	)
	goto :exit
)

:: MOVE ORIGINAL TO OLDS-FOLDER
move /y "%db_file_path%%db_file_name%.tmp" "olds/%old_db_backup_file_name%"
if %ERRORLEVEL% NEQ 0 (
	SET ERROR_MSG=Could not move result database to olds folder: %db_file_path%%db_file_name%.tmp

	@echo on
	@echo %ERROR_MSG% 
	@echo "%ERROR_MSG%" >> "logs/"%TimeStamp%-BatchFileError.log
	@echo off

	goto :error
)

goto :exit

:error
exit /b 1

:exit