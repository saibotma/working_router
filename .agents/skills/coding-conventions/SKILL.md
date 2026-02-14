---
name: coding-conventions
description: Use this skill when doing any work that has to do with code
---

- Order content of code files by importance; The most important content that most represents the file name should be on
  top, less important code below
- Make classes that have the sole purpose to contain or transport data "data classes"
- Don't make variable or parameter names longer than required by the context; E.g. for a variable of type
  `AvatarImageSize` inside the class `AvatarImage` it is sufficient to have name `size` instead of `avatarImageSize`,
  unless the longer name is really necessary due to other reasons
- When content of a file change drastically always reevaluate whether the name and location of the file are still
  appropriate; Rename and/or relocate when necessary
- Never remove existing comments from code; only remove them when changing the code and the comments no longer apply
