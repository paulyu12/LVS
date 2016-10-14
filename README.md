# LVS
Ubuntu16.04 配置 LVS+Keepalived 负载均衡

一. 实验环境

  客户主机：Windows
  
  LVS Director1: Ubuntu16.04 (IP: 192.168.159.137), MASTER
  
  LVS Director2: Ubuntu16.04 (IP: 192.168.159.136), BACKUP
  
  Real Server1: Ubuntu16.04 (IP: 192.168.159.131)
  
  Real Server2: Ubuntu16.04 (IP: 192.168.159.138)
  
  VIP：192.168.159.130(虚拟IP，并不是一个真正的主机，而是在LVS Director和Real Server上都要配的IP）
  
  实验中，在Real Server上配置了Apache2服务用来查看访问和负载均衡效果。
  
二. 实验目的

  利用LVS DR模式实现负载均衡，利用keepalived对Director和Real-server保活，从而实现高可用。
  
三. 原理

  LVS DR模式：客户机对VIP的请求先到LVS Director，LVS Director将请求包的目的MAC地址改成自己同一网段下的Real Server的MAC地址再转发出去。因为在每个Real Server上都配有VIP, 所以Real Server会认为这是对本机的请求，所以将应答包直接返回给客户机。
  
  Keepalived: 在MASTER(LVS Director1)和Backup(LVS Director2)上分别配置keepalived, MASTER的优先级高于BACKUP的优先级，keepalived在局域网中选举出MASTER承担转发任务。当MASTER出现故障，keepalived通过监测和检查可以实时发现并将转发任务切换到BACKUP上。当MASTER修复并重新上线，因为MASTER的优先级高，则会立即抢占，仍由MASTER转发。
  
四. 文件使用方法
  1. LVSserver_main.sh和LVS.conf放到LVS Director主机上，脚本会自动安装apache2, keepalived和ipvsadm
  
     给与LVSserver_main.sh执行权限，如：
     
        sudo chmod +x LVSserver_main.sh
        
     给LVS.conf读权限，貌似默认是有的，不必修改。
     
     修改LVS.conf文件内容：
     
        interface: LVS_Director上的网卡名称，VIP将配置在该网卡上；
        
        router_id: LVS_Director唯一标识，可以自定义，但MASTER和BACKUP不可以相同；
        
        lvs_ip: 你要配置的VIP；
        
        lvs_port: 接收客户机请求的端口号；
        
        balance_algorithm: 转发算法，实验中使用的rr, 效果明显，你也可以改成wrr等；
        
        persistence_timeout: 持续时间，在持续时间内，Director会将请求转发给同一主机，为了效果明显，实验中使用persistence_timeout=0；
        
        protocol: TCP 或 UDP；
        
        type: MASTER 或 BACKUP, 在LVS Director1上使用 MASTER, 在LVS Director2上在LVS.conf文件中把它改成BACKUP；
        
        priority: 优先级， 在MASTER上设为200（可以自定）， 在BACKUP上值小于MASTER，一说要至少小50，就设成100吧；
        
        real_server: 承担服务和请求任务的实际服务器IP，写在数组real_server里，可追加或删除；
        
        real_server_port: real_server的服务端口。
        
     在root用户下执行命令
     
        ./LVSserver_main.sh
        
     注：实际上LVS Director不用安装apache2服务，实验中keepalived实时检查apache2服务是否active, 如果down掉了，重启无效后立即关掉本机上的keepalived，并将转发任务切到BACKUP上。如果你有其它检查Director是否down掉的方法，可以不安装apache2，执行上面脚本后在/usr/local/check_apache2.sh中修改检查方法。
     
  2. realserver_main.sh和realserver_config.sh放到Real Server上， 脚本自动安装apache2服务
  
     给realserver_main.sh执行权限， realserver_config.sh的执行权限在realserver_main.sh中做了处理，所以不用管。
     
     在root用户下执行命令:
     
        ./realserver_main.sh VIP
        
     其中，VIP是和你在Director上配置的VIP相同。
     
     修改apache2主页面：
     
        gedit /var/www/html/index.html
        
     在index.html文件中编辑并保存此Real Server的显示内容，为了区分不同Real Server，建议在配置不同Real Server时，编辑不同的内容， 如
     
        &lt;p&gt;This is Real Server * &lt;/p&gt;
        
     其中 * 指的是Real Server编号。
     
     
     注：realserver_main.sh的功能是安装apache2服务，并调用realserver_config.sh脚本配置Real Server. 最后，把配置脚本realserver_config.sh添加到开机自启动中。 运行过一次./realserver_main.sh VIP后，如果你想重新配置，可以直接使用
     
        ./realserver_config.sh VIP start
        
        如果你想删除Real Server配置，可以直接使用
        
        ./realserver_config.sh VIP stop
        
五. 测试
  1. 测试负载均衡
  
      在客户机上浏览器输入192.168.159.130，并访问；
      
      使用 ctrl+F5 从服务器端刷新，由于配置的是 rr 轮转算法且持续时间为0，可以看到，每次访问的是不同的Real Server上的index.html页面。
  
  2. 测试主备切换
  
     MASTER，BACKUP和两台Real Server都配置好了之后，在MASTER上执行命令
     
        ip a
        
     可以看到一条
     
        inet 192.168.159.130/32 scope global ens33
        
     说明此时转发任务在MASTER上，而BACKUP上看不到这条反馈。当关掉MASTER上的Keepalived后
     
        service keepalived stop
        
     在BACKUP上执行
     
        ip a
        
     可以看到
     
        inet 192.168.159.130/32 scope global ens33
        
     此时任务已经切到BACKUP上。
     
     但是，在MASTER上重启keepalived
     
        service keepalived restart
        
     则MASTER会重新抢占。
     
  3. 测试Real Server down掉的情况
  
     在承担转发任务的Director上执行命令：
     
        ipvsadm -L -n
        
     查看此时的Real Server列表，如果某台 Real Server在列表中，Director会向它转发，反之则不会。
     
     关掉任何一台Real Server上的apache2服务，或者直接关机，此时在承担转发任务的Director上执行命令：
     
        ipvsadm -L -n
        
     可以看到down掉的Real Server从转发列表中删除了，此时再从客户机请求VIP, 即192.168.159.130，只能看到剩余的Real Server的响应页面。
     
     重新恢复down掉的Real Server，则又在转发列表中看到 Real Server了，也能正常承担服务了。
  
  
  
