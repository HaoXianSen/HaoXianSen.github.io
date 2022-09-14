# Personal Blog
[harry blog](https://haoxiansen.github.io)

# Quickstart
0. fork [blog project](https://github.com/HaoXianSen/HaoXianSen.github.io)
0. rename
### Quick auto start
    open your terminal, and `sh install.sh`
### manual
    0. install [jekyll](https://jekyllrb.com/docs/)
    0. bundle install
0. modify
   - change configuration to fit your style
   - add new article into `_post` directory
0. bundle exec jekyll serve
    - change directory(cd) to project root
    - run `bundle exec jekyll serve --incremental`
0. push into master after confirmed

start write a blog you can execute  ``` sh auto_install.sh ```
if you need psot a blog you an execute ``` sh auto_push.sh ```

记录一下我使用的图片上传工具
Typora 为我们提供了多种图片上传工具

![image-20220829154029481](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/image-20220829154029481.png)

OK，具体的可以参考[文档](https://support.typora.io/Upload-Image/)

其中我使用了upic， 其实安装也很简单，从[github](https://github.com/gee1k/uPic) 下载release，拖到application里，然后运行，然后配置偏好设置，添加github的配置

![image-20220829154256437](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/image-20220829154256437.png)

# Useful CMD

0. count `post key` from `ls _posts/* | grep "md" | wc -l`, first beginning is zero

# Reference
0. [layouts](https://tianqi.name/jekyll-TeXt-theme/docs/zh/layouts#aside)
0. [doc](https://tianqi.name/jekyll-TeXt-theme/docs/zh/quick-start)
0. [kitian616](https://github.com/kitian616/kitian616.github.io)
0. [xlagrange](https://github.com/XLagrange/xlagrange.github.io)
0. [jekyllrb directory structure](https://jekyllrb.com/docs/structure/)
