" Vim autoload file for editing compressed files.

fun gzip#read(cmd)
  call v:lua.require('gzip').read(a:cmd)
endfun

fun gzip#write(cmd)
  call v:lua.require('gzip').write(a:cmd)
endfun

fun gzip#appre(cmd)
  call v:lua.require('gzip').appre(a:cmd)
endfun
