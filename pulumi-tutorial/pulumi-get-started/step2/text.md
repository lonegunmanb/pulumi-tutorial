# 配置 PATH 并验证版本

把 `~/.pulumi/bin` 加入 `PATH`，并写入 `~/.bashrc` 让新开的终端也能用：

```bash
export PATH="$PATH:$HOME/.pulumi/bin" && \
echo 'export PATH="$PATH:$HOME/.pulumi/bin"' >> ~/.bashrc
```{{exec}}

验证 CLI 是否就绪：

```bash
pulumi version && \
pulumi help
```{{exec}}

如果打印出形如 `v3.x.x` 的版本号，说明 Pulumi 已经可用。若提示 `command not found`，几乎都是 `PATH` 没配好，重新执行上面的 export 即可。