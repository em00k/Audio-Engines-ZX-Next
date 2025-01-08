@echo off

echo Building Project... > err

sjasmplus --zxnext --nologo ASM\MAIN.ASM

type err
