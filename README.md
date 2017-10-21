Yet another bgfx lua binding library
=============

This is my style bgfx lua (5.3) binding library (work on process), and I rewrote parts of bgfx original examples in lua.

The lua version examples are not efficent but only for testing. 

To build the library, you should build bgfx static library first, or you can download my [win64 pre-compile version](https://github.com/cloudwu/lua-bgfx/releases) .

I use [IUP](http://webserver2.tecgraf.puc-rio.br/iup/) for GUI framework, you can also download the [win64 pre-compile version](https://github.com/cloudwu/lua-bgfx/releases/download/v0.1/iup.zip) .

To test it, just put `iup.exe` , `math3d.dll` , `bgfx.dll` in the same directory with the asserts (textures/shaders/meshes) from bgfx , and run :

> iup.exe 00-helloworld.lua

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

The MIT License
=====

Copyright 2017 云风 cloudwu@gmail.com

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
