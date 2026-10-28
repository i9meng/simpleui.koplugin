local count=0
for path in io.lines(assert(arg[1])) do
    local f,err=loadfile(path)
    assert(f,err)
    count=count+1
end
print('PASS '..count..' Lua files compile ('..(jit and jit.version or _VERSION)..')')
