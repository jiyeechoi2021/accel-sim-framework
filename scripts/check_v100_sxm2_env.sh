#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
BASE_LOG_DIR="./repro_logs/v100_sxm2_env_check"
LOG_DIR="${BASE_LOG_DIR}/${TS}"
LATEST_LINK="${BASE_LOG_DIR}/latest"

mkdir -p "${LOG_DIR}"

echo "[INFO] Log directory: ${LOG_DIR}"

echo "[INFO] Host info"
{
  hostname || true
  uname -a || true
  lsb_release -a 2>/dev/null || true
  cat /etc/os-release 2>/dev/null || true
} | tee "${LOG_DIR}/host_info.txt"

echo "[INFO] Git info"
{
  pwd
  git branch --show-current || true
  git status || true
  git remote -v || true
  git log -1 --oneline || true
} | tee "${LOG_DIR}/git_info.txt"

echo "[INFO] GPU list"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi -L | tee "${LOG_DIR}/nvidia_smi_L.txt"

  echo "[INFO] GPU query"
  nvidia-smi --query-gpu=name,memory.total,power.limit,clocks.gr,clocks.mem,driver_version --format=csv \
    | tee "${LOG_DIR}/nvidia_smi_query.csv"

  echo "[INFO] Clock, power, temperature"
  nvidia-smi -q -d CLOCK,POWER,TEMPERATURE \
    | tee "${LOG_DIR}/nvidia_smi_clock_power_temp.txt"

  echo "[INFO] Supported clocks"
  nvidia-smi -q -d SUPPORTED_CLOCKS \
    | tee "${LOG_DIR}/nvidia_smi_supported_clocks.txt" || true
else
  echo "[WARN] nvidia-smi not found. This is expected in Codespaces, but not on the GPU server." \
    | tee "${LOG_DIR}/nvidia_smi_missing.txt"
fi

echo "[INFO] CUDA compiler"
if command -v nvcc >/dev/null 2>&1; then
  nvcc --version | tee "${LOG_DIR}/nvcc_version.txt"
else
  echo "[WARN] nvcc not found" | tee "${LOG_DIR}/nvcc_version.txt"
fi

echo "[INFO] Nsight Compute"
if command -v ncu >/dev/null 2>&1; then
  ncu --version | tee "${LOG_DIR}/ncu_version.txt"
else
  echo "[WARN] ncu not found" | tee "${LOG_DIR}/ncu_version.txt"
fi

echo "[INFO] Creating latest symlink"
ln -sfn "${TS}" "${LATEST_LINK}"

SUMMARY="${LOG_DIR}/summary.txt"

{
  echo "=== V100 SXM2 Environment Check Summary ==="
  echo "Timestamp: ${TS}"
  echo "Log directory: ${LOG_DIR}"
  echo "Latest link: ${LATEST_LINK}"
  echo

  echo "[Host]"
  if [ -f "${LOG_DIR}/host_info.txt" ]; then
    sed -n '1,20p' "${LOG_DIR}/host_info.txt"
  else
    echo "host_info.txt not available"
  fi
  echo

  echo "[Git]"
  if [ -f "${LOG_DIR}/git_info.txt" ]; then
    sed -n '1,40p' "${LOG_DIR}/git_info.txt"
  else
    echo "git_info.txt not available"
  fi
  echo

  echo "[GPU]"
  if [ -f "${LOG_DIR}/nvidia_smi_L.txt" ]; then
    cat "${LOG_DIR}/nvidia_smi_L.txt"
  else
    echo "nvidia-smi -L output not available"
  fi
  echo

  echo "[GPU Query]"
  if [ -f "${LOG_DIR}/nvidia_smi_query.csv" ]; then
    cat "${LOG_DIR}/nvidia_smi_query.csv"
  else
    echo "nvidia-smi query output not available"
  fi
  echo

  echo "[CUDA]"
  if [ -f "${LOG_DIR}/nvcc_version.txt" ]; then
    cat "${LOG_DIR}/nvcc_version.txt"
  else
    echo "nvcc output not available"
  fi
  echo

  echo "[Nsight Compute]"
  if [ -f "${LOG_DIR}/ncu_version.txt" ]; then
    cat "${LOG_DIR}/ncu_version.txt"
  else
    echo "ncu output not available"
  fi
} | tee "${SUMMARY}"

echo
echo "[INFO] Done."
echo "[INFO] Summary file:"
echo "  ${SUMMARY}"
echo
echo "[INFO] To share the key result, run:"
echo "  cat repro_logs/v100_sxm2_env_check/latest/summary.txt"
echo
echo "[INFO] To list all generated files, run:"
echo "  find repro_logs/v100_sxm2_env_check/latest -type f | sort"
