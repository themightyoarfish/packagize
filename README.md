# README #

`packagize` is a small Ruby tool to generate a package structure from package declarations in Java files. 
For instance, if your students always submit all their code in one directory while still having `package x.y.z;` in their files, this tool will fix the mess.
It will create `bin` and `src` directories if not already present.

Run `packagize -h` for help.