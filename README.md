# Image to Ascii
Preston Engler

This repository uses cimgui and imgui as submodules, please clone using the --recursive flag

The project can be built and run with 'zig build run'
If running the executable manually after build, ensure the appropriate glfw3.dll file is in the same directory

## Acquiring libraries 
Install the Vulkan SDK from [here](https://vulkan.lunarg.com/sdk/home)
Get glfw binaries from [here](https://www.glfw.org/)

## Linking libraries 
If on Windows, you must link with the glfw lib-static-ucrt files to get it working with the Zig linker
