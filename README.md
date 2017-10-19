bgfx Lua 封装
=============

bgfx 是一个跨平台图形渲染库，你可以基于它来封装自己的 3d engine https://github.com/bkaradzic/bgfx 。

bgfx 已有一个 lua api binding ，但是我不太满意，所以自己重新做一个。

这个封装库还在开发中，并没有全部封装 bgfx 的 C API ，我的计划是逐步移植 bgfx 的 examples 到 lua ，在移植过程中封装用到的 API 。注意：这里的 example 只是一一翻译 C++ 代码，用于验证 lua api 的正确性。在 C++ 里没有性能的做法，到 lua 中可能就有严重的性能问题。所以有些 example 会比较低效。如果需要高效运行，还需要找到合适 lua 的方法重构。

这里使用了 lua iup 作为跨平台窗口驱动，理论上也可以自己另外实现窗口系统，只需要向 lua bgfx 提供窗口句柄即可。


编译
=====

编译这个库需要先编译好 bgfx 静态库，如果你只想测试 lua 部分，可以下载[预编译版本](https://github.com/cloudwu/lua-bgfx/releases) 。

运行
=====

需要在源码当前目录运行 iup.exe 0x-xxx.lua ，资源目录 meshes/shaders/textures 必须在当前目录。它们是从 bgfx/examples/runtime 拷贝过来。

iup 基于 https://github.com/cloudwu/iupmingw/ 编译，可以自己编译，也可以 [下载预编译好的版本](https://github.com/cloudwu/lua-bgfx/releases/download/v0.1/iup.zip) (windows 64bit)。

LICENSE
=====
和 bgfx 相同，采用 BSD 2-clause "Simplified" License
