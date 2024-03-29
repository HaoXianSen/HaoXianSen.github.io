---
title: 基于homebrew 的code lint 集成
tags: swift CLI objective-c homebrew 
key: 122 
published: true
article_header: 
  type: cover
  image:
    src: https://img.win3000.com/m00/2d/73/e36fcc83fcdbc010e70eee813a13d17c.jpg 
---



### 基于homebrew 的code lint 集成(总)

#### 前情

之前文章中我们已经讲到了采用pre-commit 集成工具去集成code lint 工具（[Objective-CLint](https://haoxiansen.github.io/2022/09/14/Objective_CLint.html)、swiftlint），[文章地址](https://haoxiansen.github.io/2022/08/29/%E5%85%B3%E4%BA%8EiOS-%E4%BB%A3%E7%A0%81%E8%B4%A8%E9%87%8F%E6%8A%8A%E6%8E%A7%E7%A0%94%E7%A9%B6.html)，这种方式当然很方便，但是也很难扩展。比如swiftLint 我们就没有很好的办法让其以html或者其他的方式打开，只能显示到控制台，再比如我们后续想要整合oc和swift lint的结果。也没有好的办法实现。那么我们就要另辟西路。

当然我们还是采用pre-commit 的时期，只是我们不在采用pre-commit工具集成，我们自己写pre-commit脚本、自己做工具的安装等等时期。

这样我们的可扩展行很强，我们想干什么都可以，只要我们能想的到的...

#### 开发/架构

##### 开发前景

首先我们需要开发一个类似于pre-commit工具的安装CLI。作为我们自己的pre-commit工具，它主要包含三个功能: 

1. pre-commit 脚本文件的移动；
2. Objective-CLint 、swiftLint 配置文件的下载+移动；
3. Objective-CLint、swiftLint 的安装。

###### 疑问？为什么我们不用现成的[pre-commit](https://pre-commit.com/)工具

为什么我们不用现成的pre-commit工具，直接配置.pre-commit-config.yaml yaml文件直接使用呢？

不得不承认，pre-commit确实很好的支持了hooks，并且做到了整合所有hooks的工具。但是pre-commit仍然无法满足我们的一些需求。比如我们想要oclint之后能打开一个错误写法与正确写法相比较的html，swiftlint 能够打开一个lint之后错误、警告的html。这个时候如果原本的hooks并没有支持，他只是支持输出html，那么pre-commit将会限制我们的可定制化。也就是说，pre-commit确实好用，但是如果要实现一些可定制化的要求，它必须是hooks库本身就支持的，否则将无法完成可定制化或者需要一些非常规手段实现。

##### 整体架构

###### 整体架构图：

![image-20230327114420359](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230327114421image-20230327114420359.png)

整体我们采用homebrew 作为基础。在homebrew 的基础上我们创建自己的三方tap，作为存储自研库GZLintMaker、Objective-CLint 存储空间，也方便后续的使用、安装。swiftLint 已经支持homebrew的安装，所以我们不需要管。如果不知道homebrew 如何创建三方tap，请参考我前边的文章[这里](https://haoxiansen.github.io/2023/02/03/%E5%88%9B%E5%BB%BA%E4%B8%89%E6%96%B9homeBrew.html)

###### GZLintMaker 自制CLI（傻瓜式安装、使用）

​	想要学习怎么用swift写CLI工具的，请参考[这里](https://haoxiansen.github.io/2023/01/05/01_Swift-%E6%9E%84%E5%BB%BACLI.html)

​	GZLintMaker 功能结构

<img src="https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230526110210image-20230526110209988.png" alt="image-20230526110209988" style="zoom:40%;" />

GZLintMaker 是基于swift 写的一个CLI（Command-line interface， 命令行工具）。作为一个iOSer， 能够使用swift 去写CLI 工具其实也是一键很幸福的事情（题外话）。

###### GZLintMaker 功能命令介绍

GZLintMaker 主要包含紫色三部分功能， --install --clean --uninstall，我们先分别介绍一下这几个功能：

* **--install**  

  作为install 的flag命令。主要内容就是安装codeLint的所有内容。

  * 移动配置文件、hook 脚本文件

    首先它会去默认的存放配置文件、执行脚本的git仓库，去clone 仓库内容。clone 完成			之后，我们把仓库里的.clang-formate . swiftlint移动到工程目录下（根目录）；将.pre-commit 脚本文件移动到.git/hooks/目录下，当然我们要确保这是一个基于git的仓库。最后我们删除远程存放这些文件的目录。
    <img 		src="https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230526111628image-20230526111628810.png" alt="image-20230526111628810" style="zoom:50%;" />
    		
    
  * lint 工具检查
  
    检查项有：
  
    * homebrew，没有则安装
    * homebrew tap （https://github.com/haoxiansen/homebrew-private）安装/更新
    * Objective-CLint 安装/更新
    * swiftLint 安装/更新
    * coreutils 安装(用来脚本时长统计)
  
* **--clean**

  清理当前工作空间

  * 清理配置文件.clang-formate .swiftlint 
* 清理脚本文件 pre-commit
  * 清理配置文件存放的git 仓库目录（如果有的话）

* **--uninstall**

  卸载Lint工具

  * ObjectiveC-lint
  * swiftLint

* **--project-path**

  安装工作目录， 如果未指定默认为当前目录为工作目录

  * 可以和所有一级命令配合使用，作为指定工作目录

* **--configure-git-path**

  * 配置文件、脚本的git仓库
  * 需要指定自己的git 仓库作为自适应配置。仓库必须包括.clang-format .swiftlint 配置文件以及pre-commit脚本文件
  * 如果没有指定，默认使用我们的git仓库的配置作为配置
  * 为什么要采用单独的一个库作为配置文件、脚本文件的存储呢？主要是在于更新快，如果我们的pre-commit脚本、或者配置文件有更新，只要执行lintMaker --install 就可以更新


###### pre-commit 脚本介绍

pre-commit 主要做了以下几件事情：

* lint 工具的执行
  * 使用git diff --cached --named-only 删选出.h .hh .m .mm作为OC 文件，然后判断是否需要lint或者执行ObjectiveC-Lint的命令 `format-objc-hook --reporter "open_html" --output "${objc_lint_html_dir}" --quiet`
  * 同样使用git diff --cached --named-only 删选出.swift 文件作为swift 文件，然后判断是否需要lint或者执行swiftlint 命令`swiftlint lint --quiet --reporter html --output "${swift_lint_html_dir}" "${lint_swift_files[*]}"`
* lint 工具执行时间的统计
  * 因为MacOs 自带date 命令行工具只能支持秒级别的时间，无法满足我们更精细的时间统计要求，所以我们也是在Lint工具安装的时候特意带着coreutils库。这个库支持了更精细的gdate命令
  * 使用gdate分别在脚本开始和结束统计纳秒时间，然后进行相减 & 转化为秒数展示
* lint 工具输出的可视化（打开html）
  * ObjectiveC-Lint 因为是自己的库，什么命令都好支持，所以支持了指定输出文件
  * swiftlint 本身支持了多种输出方式，并且可指定输出文件
  * 这样我们在判断执行结果后，判断是否需要提示 & 打开html

下面是pre-commit的整体脚本文件：

```shell
#!/usr/bin/env bash
# File generated by harry

HERE="$(cd "$(dirname "$0")" && pwd)"
WHITE="37"
RED="31"
GRAY="90"
RED_BACKGROUND="41m"
GREEN_BACKGROUND="42m"
SYAN_BACKGROUND="46m"
CACHE="${HERE}/.cache/"


function swift_files_to_format() {
	files=$(git diff --cached --name-only | grep -e '\.swift$')
	echo "$files" | grep -v 'Pods/' | grep -v 'Carthage/' >&1
}

function objc_files_to_format() {
	files=$(git diff --cached --name-only | grep -e '\.h$' -e '\.hh$' -e '\.m$' -e '\.mm$')
	echo "$files" | grep -v 'Pods/' | grep -v 'Carthage/' >&1
}

# params prefix, string, color, background_color, suffix
function log_color() {
    local prefix=$1
    local status=$2
    local status_color=$3
    local status_background_color=$4
    local is_r=$5
    if [[ -z "${status_background_color}" ]]; then
        if (( "$is_r" == 1 )); then
            printf "%s\033[%sm%s\033[0m\r" "${prefix}" "${status_color}" "${status}"
        else 
            printf "%s\033[%sm%s\033[0m\n" "${prefix}" "${status_color}" "${status}"
        fi
        
    else
        if (( "$is_r" == 1 )); then
            printf "%s\033[%s;%s%s\033[0m\r" "${prefix}" "${status_color}" "${status_background_color}" "${status}"
        else 
            printf "%s\033[%s;%s%s\033[0m\n" "${prefix}" "${status_color}" "${status_background_color}" "${status}"
        fi
    fi
}

# log lint tool [prefix]......[sufix][color][backgroundColor][status][is_r]
function log_color_dot() {
    terminal_width=$(tput cols)
    local prefix=$1
    local suffix=$2
    local status=$3
    local status_color=$4
    local status_background_color=$5
    local is_r=$6
    prefix_length=${#prefix}
    suffix_length=${#suffix}
    status_length=${#status}
    dot_length="$terminal_width - $prefix_length - $suffix_length - $status_length - 10"
    dot_string=""
    for((i=0;i<"$dot_length";i++)); do
        dot_string="${dot_string}""."
    done

    log_color "${prefix}${dot_string}${suffix}" "$status" "$status_color" "$status_background_color" "$is_r"
}

function print_exec_time() {
    start_time=$1
    end_time=$2
    # use bc command
    elapsed_time=$(echo "${end_time} - ${start_time}" | bc)
    # convert um to s
    seconds_time=$(echo "scale=2; ${elapsed_time} / 1000000000.0" | bc)
    echo "$seconds_time"
}

# objc files lint
function lint_objc() {
    return_code=0
    start_time=$(gdate +%s%N)
    external_log=""
    if [ "$(command -v format-objc-hook)" ]; then
        prefix="[format-objc]"
        log_color_dot "$prefix" "" "Linting" "${WHITE}" "${GREEN_BACKGROUND}" "1"
        lint_objc_files=$(objc_files_to_format)
        if [ -z "${lint_objc_files[*]}" ]; then
            log_color_dot "$prefix" "(no files to check)" "Skiped" "$WHITE" "$SYAN_BACKGROUND" "0"
        else
            objc_lint_html_dir="${CACHE}"objclint.html
            format-objc-hook --reporter "open_html" --output "${objc_lint_html_dir}" --quiet
            lint_result=$?
            if (( "$lint_result" == 0 )); then
                log_color_dot "$prefix" "" "Success" "${WHITE}" "$GREEN_BACKGROUND" "0"
            else 
                return_code=1
                log_color_dot "$prefix" "" "Failed" "${WHITE}" "$RED_BACKGROUND" "0"
                external_log="❌ 已自动打开html，请修复html中的lint问题，之后再次commit...😭😭😭"
            fi
        fi
    else 
        return_code=1
    fi
    end_time=$(gdate +%s%N) 
    duration_seconds=$(print_exec_time "$start_time" "$end_time")
    format_seconds=$(printf "%.2f" "$duration_seconds")
    printf "\033[%dm- duration: %ss\033[0m\n" "${GRAY}" "${format_seconds}"

    if [[ -n "${external_log}" ]]; then
        log_color "❌ 已自动打开html，请修复html中lint问题，之后再次commit...😭😭😭" "" "${RED}" "" "0"
    fi
    return "${return_code}"
}

# swift files lint
function swift_lint() {
    return_code=0
    start_time=$(gdate +%s%N)
    external_log=""
    
    if [ "$(command -v swiftlint)" ]; then
        prefix="[swiftlint]"
        log_color_dot "$prefix" "" "Linting" "${WHITE}" "${GREEN_BACKGROUND}" "1"
        lint_swift_files=$(swift_files_to_format)
        if [ -z "${lint_swift_files[*]}" ]; then
            log_color_dot "$prefix" "(no files to check)" "Skiped" "$WHITE" "$GREEN_BACKGROUND" "0"
        else
            swift_lint_html_dir="${CACHE}"swiftlint.html
            swiftlint lint --quiet --reporter html --output "${swift_lint_html_dir}" "${lint_swift_files[*]}"
            lint_result=$?
            if (( "$lint_result" == 0 )); then
                log_color_dot "$prefix" "" "Success" "${WHITE}" "$GREEN_BACKGROUND" "0"
            else 
                return_code=1
                open "${swift_lint_html_dir}"
                log_color_dot "$prefix" "" "Failed" "${WHITE}" "$RED_BACKGROUND" "0"
                external_log="❌ 已自动打开html，请修复html中的lint问题，之后再次commit...😭😭😭"
            fi
        fi
    else 
        return_code=1
    fi
    end_time=$(gdate +%s%N) 
    duration_seconds=$(print_exec_time "$start_time" "$end_time")
    format_seconds=$(printf "%.2f" "$duration_seconds")
    printf "\033[%dm- duration: %ss\033[0m\n" "${GRAY}" "${format_seconds}"
    if [[ -n "${external_log}" ]]; then
        log_color "❌ 已自动打开html，请修复html中lint问题，之后再次commit...😭😭😭" "" "${RED}" "" "0"
    fi
    return "${return_code}"
}

if ! [ -d "${CACHE}" ]; then
    mkdir "${CACHE}"
fi

lint_objc
objc_code=$?
echo "" && swift_lint
swift_code=$?
echo "" 
if (( "$objc_code" == 0 )) && (( "$swift_code" == 0 )); then
    exit 0
else 
    exit 1
fi

```

###### ObjectiveC-Lint

ObjectiveC-Lint 有专刊介绍，感兴趣的话可以去[瞅瞅!](https://haoxiansen.github.io/2022/09/14/Objective_CLint.html)

###### SwiftLint

SwiftLint 就没有什么可说的了，强大&实用&支持各种方式接入~，感兴趣的可以去[github](https://github.com/realm/SwiftLint)!

#### 使用

* 直接采用Unix可执行文件

  * 去[github](https://github.com/HaoXianSen/LintMaker/releases) 下载可执行文件，直接使用 | 放入urs/local/bin下

* HomeBrew方式

  * ``` shell
    brew tap haoxiansen/private
    ```

  * ```shell
    brew update 
    ```

  * ```shell
    brew install lintmaker && brew upgrade lintmaker
    ```
    
  * ``` shell
    lintmaker --install


#### 效果展示

* 无可检查文件
  * ![image-20230606162944764](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230606162944image-20230606162944764.png)
  
* 存在问题

  * ![image-20230606163221890](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230606163222image-20230606163221890.png)

* oc-lint 成功， swiftlint 跳过

  ![image-20230606163204367](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230606163204image-20230606163204367.png)

  ![image-20230606163258916](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230606163259image-20230606163258916.png)

  ![image-20230606163316722](https://cdn.jsdelivr.net/gh/HaoXianSen/HaoXianSen.github.io@master/screenshots/20230606163316image-20230606163316722.png)

#### 方案改进（2023.12.18）

* 当前方案存在的问题

  * **hooks脚本不受git版本控制**。因为git hooks 是不受git版本控制的，也就是说它是本地的。那么就会存在新拉的库（已经加入codelint），hooks脚本不存在。也就没了code lint 检查。
  * **库必须执行lintmaker 命令才会加入config文件（.clang-format, .swiftlint.yml）。** 如何能更加简便的进行，并且可控。是当前要面临的又一大难题。

* 解决方案

  预想解决方案大概有两种：

  1. 将hook script 加入到库根目录，执行某个命令的时候，将hook script copy到.git/hooks/下
  2. 将hook script 放到个人目录下的.git-template/hooks/下，这个git 模版目录下的脚本，每次git clone | git init 会将模版文件copy到.git/hooks/下

  ok。我们现在来分析一下以上两种方案：

  ♥️首先看一下第二种方案，这种方案来说，能满足我们首次进行git clone 和git init 命令后copy 脚本的需求，但是假如是以下的情况

  如果库a，b两同学已经都clone到了本地，随后a 同学加入了code lint。那么b同学是不会执行到git clone 或者git init 操作。那么也就是无法同步到b同学了。

  ♥️既然第二种方案，还是无法达到我们预期，那我们来看第一种方案。首先我们可以在项目根目录，建立一个hooks/目录存放脚本文件，然后通过lintmaker 命令，进行链接，也就是ln -s -f ../../hooks/pre-commit  pre-commit。

  同样这种情况也存在以上问题，也就是说b同学必须要执行一次lintmaker 命令，如果b同学没有执行，那么代码就不会被code lint。

  ♥️看来以上两种预想方案都行不通，主要的问题还是我们没法搞定自动同步的问题。那么对于IOS 工程有什么命令是我们肯定执行的呢？很明显Cocoapods命令，那么我们从这条路出发，我们可以写一个Cocoapods hooks脚本，让其在pre-instal 或者post-install去检查当前库，以及子库以path引用的库，是否拥有hooks脚本，如果没有，我们就将hooks脚本进行移动。当然，我们可以配合1 + 2 两种方案进行。

  ♥️基于以上方案，还有一个问题，如何控制打包的时候不去进行这项检测？

* 👌那么我们详细策划一下整体解决方案

  采用iOS 工程特有的pod hook的机制，在pod install的时候进行检测壳工程及开发子库的lint配置文件是否存在，如果存在说明，当前已经加入了lint， 那么将pre-commit文件 copy 到.git/hooks/目录下，另外还有一个问题



#### 总结

- 整个code lint tool的集成断断续续花费了半年多的时间，整体上还是比较满意的
- code lint 的接入，能够使得我们的代码更加的规范化，减少人工review的成本；
- code lint的接入从某种程度上会降低我们的开发效率，因为要lint时间 + 改正时间，但是带来的好处远远大于一点点的效率降低，等到规则规范都提升之后，我们的效率自然会再次提起来
- 目前我们对ObjectiveC-Lint 做了进一步优化，支持了更多的









