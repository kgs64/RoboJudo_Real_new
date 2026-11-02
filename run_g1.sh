#!/usr/bin/env bash
set -euo pipefail

cd /home/unitree/RoboJu/RoboJudo_Real_new

PY="/home/unitree/miniconda3/envs/robojudo/bin/python"

export PATH="/home/unitree/miniconda3/envs/robojudo/bin:$PATH"
export PYTHONPATH="$PWD${PYTHONPATH:+:$PYTHONPATH}"
export UNITREE_NET_IF="enP8p1s0"

CONFIG="g1_native_loco_mimic_23dof_backpack"

# 检查运行环境
if pgrep -f '[p]ython.*scripts/run_pipeline.py' >/dev/null; then
    echo "错误：已有 RoboJudo 控制程序运行"
    exit 1
fi

if ! grep -q "$CONFIG" start.sh; then
    echo "错误：start.sh 的真机配置需要检查"
    exit 1
fi

if ! grep -q '^RECORD_TRAJECTORY=True' start.sh; then
    echo "错误：数据采集未开启"
    exit 1
fi

echo "================================"
echo "G1 BeyondMimic"
echo "自动检测当前策略模型"
echo "================================"

# 从真实配置读取 ONNX 路径
env -u LD_PRELOAD -u LD_LIBRARY_PATH -u CYCLONEDDS_URI \
"$PY" - "$CONFIG" <<'PY_CHECK'
import sys
from pathlib import Path
from robojudo.config.config_manager import ConfigManager

cfg = ConfigManager(config_name=sys.argv[1]).get_cfg()

if cfg.env.is_sim:
    raise SystemExit("错误：当前为仿真环境")

print("配置:", type(cfg).__name__)
print("网卡:", cfg.env.unitree.net_if)
print("环境:", cfg.env.env_type)

for policy in cfg.mimic_policies:
    model = Path(policy.policy_file)

    print("模型:", model.name)
    print("最大时间步:", policy.max_timestep)

    if not model.is_file():
        raise SystemExit(f"错误：模型不存在：{model}")

    print("模型检查通过")

print("================================")
PY_CHECK

# 只检查，不启动真机
if [[ "${1:-}" == "--check-only" ]]; then
    echo "检查完成，没有启动机器人"
    exit 0
fi

echo "开始启动 G1 控制及数据采集"
exec ./start.sh
