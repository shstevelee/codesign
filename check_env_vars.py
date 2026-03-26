import os

def verify_paths(cfg_args):
    # Mapping our internal needs to the specific Env Var names you mentioned
    path_map = {
        "OPENROAD": "PREINSTALLED_OPENROAD_PATH",
        "STREAMHLS": "PREINSTALLED_STREAMHLS_PATH",
        "SCALEHLS": "PREINSTALLED_SCALEHLS_PATH"
    }

    for label, env_key in path_map.items():
        # 1. Check the Config Dictionary (lowercase, as seen in your code)
        cfg_key = env_key.lower()
        path_from_cfg = cfg_args.get(cfg_key)

        # 2. Check the System Environment Variables (uppercase)
        path_from_env = os.environ.get(env_key)

        # Logic: Use Config first, then Env Var, then fail
        final_path = path_from_cfg or path_from_env

        if final_path:
            print(f"✅ {label} found at: {final_path}")
            if path_from_cfg:
                print(f"   (Source: Config Argument '{cfg_key}')")
            else:
                print(f"   (Source: Environment Variable '{env_key}')")
        else:
            print(f"❌ ERROR: Could not find path for {label}!")
            print(f"   Checked Config: '{cfg_key}' and Env Var: '{env_key}'")

# Simulate your self.cfg["args"]
example_cfg_args = {
    "preinstalled_scalehls_path": "/home/user/ScaleHLS-HIDA"
}

verify_paths(example_cfg_args)