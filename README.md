# to
这是一个在Linux下运行的类似于everything的工具，用于快速进入文件夹

A tool similar to everything that runs under Linux and is used to quickly enter folders



在使用前，或者创建有新的文件夹后，你需要手动更新数据库，以便于to可以找到
```
sudo updatedb
```

使用下面命令来配置to

```
sudo ./install.sh
```

to会记录你常用的文件夹，在匹配（包括模糊匹配）到后会优先排列你常用的文件夹，这是它的缓存文件夹

```
~/.to_recent_dirs
```

一些细节

```
使用 plocate 来查找文件夹，提升查找速度
使用 mktemp 写临时文件，减少并发风险。
使用 fzf 进行模糊选择
```


这是一个简陋的版本，可能会存在很多问题，如果你有更好的方案或建议可以通过下面的方式联系到我，感激不尽
```
1435900886@qq.com
```
