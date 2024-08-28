# Image to Ascii
Preston Engler

Currently only supports building on Windows using the precompiled lib-static-ucrt GLFW binary.  
This repository uses cimgui and imgui as submodules, please clone using the --recursive flag

The project can be built and run with `zig build run`  
If running the executable manually after build, ensure the appropriate glfw3.dll file is in the same directory

## Prerequisites
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

## In Case You Want To DIY
[GLFW Quick Start](https://www.glfw.org/docs/latest/quick.html)  
[GLFW Vulkan Guide](https://www.glfw.org/docs/latest/vulkan_guide.html)  
[Vulkan Tutorial (Conveniently uses GLFW)](https://vulkan-tutorial.com/Introduction)  
