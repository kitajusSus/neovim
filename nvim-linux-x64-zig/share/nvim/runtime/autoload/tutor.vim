" vim: fdm=marker et ts=4 sw=4

function! tutor#SetupVim()
    lua require('tutor').setup_vim()
endfunction

function! tutor#LoadMetadata()
    lua require('nvim.tutor').load_metadata()
endfunction

function! tutor#SetNormalMappings()
    lua require('tutor').set_normal_mappings()
endfunction

function! tutor#MouseDoubleClick()
    lua require('tutor').mouse_double_click()
endfunction

function! tutor#InjectCommand()
    lua require('tutor').inject_command()
endfunction

function! tutor#FollowLink(force)
    lua require('tutor').follow_link(vim.fn.v:true == a:force || a:force == 1)
endfunction

function! tutor#TutorFolds(...)
    return v:lua.require('tutor').folds(a:0 > 0 ? a:1 : v:lnum)
endfunction

function! tutor#GlobTutorials(name, locale)
    return v:lua.require('tutor').glob_tutorials(a:name, a:locale)
endfunction

function! tutor#TutorCmd(tutor_name)
    lua require('tutor').tutor_cmd(vim.fn.eval('a:tutor_name'))
endfunction

function! tutor#TutorCmdComplete(lead, line, pos)
    return join(v:lua.require('tutor').tutor_cmd_complete(a:lead, a:line, a:pos), "\n")
endfunction

function! tutor#EnableInteractive(enable)
    lua require('tutor').enable_interactive(vim.fn.eval('a:enable'))
endfunction

function! tutor#ApplyTransform()
    lua require('tutor').apply_transform()
endfunction
