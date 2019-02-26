# luajit-bug-report
出现在某些情况下nginx 陷入lua的死循环，定位到使用resty.core.shdict的get方法时会出现问题


定位到和线上使用的2个lua有关，神奇的是我只是require 并没有调用也会出问题，当我尝试删除一部分代码时，问题有可能变为无法复现


怀疑和luajit 的编译有关


复现方法

```
   curl  http://localhost/set;./wrk -t4 -c120 -d10  http://localhost/
```
    
