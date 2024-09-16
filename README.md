# Image to Ascii
Preston Engler

***Graphics Done With The Bare Minimum***  
<sup>why make it easy when it can be difficult</sup>

Image to Ascii is a little experimental project using Zig directly with GLFW + Vulkan.  
The goal is to make some interesting shaders (such as the name of the project) and use cimgui to modify various parameters.  
This repository uses cimgui and imgui as submodules, please clone using the --recursive flag, or by doing: `git submodule update --init --recursive`  

## Zig Build Options
Use `zig build --help` to see available build options  
Of note are the Project-Specific Options, such as `-Doptimize=ReleaseFast`. `-Doptimize=Debug` is the default when no optimization level is specified.

## Building on Linux
Install zig, glfw, vulkan-devel  
Build+run with `zig build run`  
Simple as

## Building on Windows
Currently only supports building on Windows using the precompiled lib-static-ucrt GLFW binary with glfw-3.4.  

1. Install zig from your favorite package manager, or manually if needed

2. Install the Vulkan SDK from [here](https://vulkan.lunarg.com/sdk/home)

3. Get glfw binaries from [here](https://www.glfw.org/download.html). Download the precompiled binaries and place them directly under /lib

Example folder structure: 
```
lib
└───glfw-3.4.bin.WIN64
    ├───include
    │   └───GLFW
    └───lib-static-ucrt
```

The project can be built and run with `zig build run`, this automatically adds the glfw3.dll to the path while running  
If running the executable manually after build, ensure the appropriate glfw3.dll file is in the same directory


## In Case You Want To DIY
[GLFW Quick Start](https://www.glfw.org/docs/latest/quick.html)  
[GLFW Vulkan Guide](https://www.glfw.org/docs/latest/vulkan_guide.html)  
[Vulkan Tutorial (Conveniently uses GLFW)](https://vulkan-tutorial.com/Introduction)  
