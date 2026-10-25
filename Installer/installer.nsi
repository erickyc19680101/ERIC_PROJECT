;--------------------------------
; 기본 설정
Name "Simple Installer"
OutFile "setup.exe"
InstallDir "" 
RequestExecutionLevel admin

; Modern UI 헤더 불러오기
!include "MUI2.nsh"
!include "WinMessages.nsh"

; 디렉토리 선택 화면의 그룹박스 이름 변경
!define MUI_DIRECTORYPAGE_TEXT_DESTINATION "Windchill installed location"

; 디렉토리 페이지 커스텀 함수 지정
!define MUI_PAGE_CUSTOMFUNCTION_SHOW DirectoryShow
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE DirectoryLeave
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

;--------------------------------
; 디렉토리 입력창을 강제로 비우는 함수
Function DirectoryShow
  FindWindow $R0 "#32770" "" $HWNDPARENT
  GetDlgItem $R1 $R0 1019
  SendMessage $R1 ${WM_SETTEXT} 0 "STR:"
FunctionEnd

;--------------------------------
; 디렉토리 페이지에서 Next를 누를 때 site.xconf 존재 여부 검사
Function DirectoryLeave
  IfFileExists "$INSTDIR\site.xconf" PathOk
    MessageBox MB_ICONEXCLAMATION|MB_OK "Windchill is not installed in the directory you selected."
    Abort
  PathOk:
FunctionEnd

;--------------------------------
; [실제 설치 단계] 중복 패치 검사, wt.properties 수정, licensing 디렉토리 생성 및 파일 변환 복사
Section "WindchillConfigInstall"
  Var /GLOBAL PropPath
  StrCpy $PropPath "$INSTDIR\codebase\wt.properties"

  IfFileExists "$PropPath" 0 FileMissing

    ; PowerShell로 기존 패치 여부 검사 (isUpgradeRunning=true 검사), 속성 파일 수정, 디렉토리 생성 및 파일 복사 처리
    StrCpy $R0 `powershell -NoProfile -Command "$$p = '$INSTDIR\codebase\wt.properties'; $$content = Get-Content $$p -Encoding Default; if ($$content -match 'com\.ptc\.windchill\.upgrade\.isUpgradeRunning=true') { exit 100 }; $$n = foreach ($$l in $$content) { $$l; if ($$l -match 'com\.ptc\.windchill\.search\.verbose=false') { 'com.ptc.windchill.upgrade.isUpgradeRunning=true' } }; $$n | Set-Content $$p -Encoding Default; $$dir = '$INSTDIR\codebase\wt\licenseusage\licensing'; if (-not (Test-Path $$dir)) { New-Item -ItemType Directory -Path $$dir -Force | Out-Null }; $$srcDir = '$EXEDIR\files'; if (Test-Path "$$srcDir\WindchillInstall00001") { Copy-Item "$$srcDir\WindchillInstall00001" "$$dir\SynchronizeLicense.class" -Force }; if (Test-Path "$$srcDir\WindchillInstall00002") { Copy-Item "$$srcDir\WindchillInstall00002" "$$dir\UpdateLicenseFeature.class" -Force }" `
    
    ExecWait $R0 $R2
    
    ; PowerShell에서 exit 100(이미 패치됨)을 반환한 경우 처리
    StrCmp $R2 "100" AlreadyPatched InstallDone

  AlreadyPatched:
    MessageBox MB_ICONEXCLAMATION|MB_OK "The Windchill was already patched"
    Quit

  FileMissing:
    MessageBox MB_ICONEXCLAMATION|MB_OK "codebase\wt.properties 파일을 찾을 수 없습니다."
    Abort

  InstallDone:
    MessageBox MB_OK|MB_ICONINFORMATION "설치가 완료되었습니다!"
    Quit
SectionEnd