#!/bin/bash
git fetch
git stash .
git pull origin master
git stash pop
git status 
git add .
git commit -m "更新文章"
git status
git push origin master
