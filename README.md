zig build run
zig build -Doptimize=ReleaseSmall upx
zig build -Dtarget=x86_64-windows -Doptimize=ReleaseSmall
