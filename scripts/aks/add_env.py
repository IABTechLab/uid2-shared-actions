import yaml
import argparse

def add_env_variables(yaml_file, container_name, env_vars):
    """
    Adds multiple environment variables to a specified container in a Kubernetes YAML file.
    Args:
        yaml_file (str): Path to the YAML file.
        container_name (str): Name of the container to modify.
        env_vars (list): List of dictionaries, each containing 'name' and 'value' of an env var.
    """
    try:
        with open(yaml_file, 'r') as file:
            data = list(yaml.safe_load_all(file))

        modified = False

        for doc in data:
            if doc and doc.get('kind') == 'Deployment':
                containers = doc['spec']['template']['spec']['containers']
                for container in containers:
                    if container['name'] == container_name:
                        if 'env' not in container:
                            container['env'] = []
                        for env_var in env_vars:
                            container['env'].append(env_var)
                        modified = True
                        break

        if modified:
            with open(yaml_file, 'w') as file:
                yaml.dump_all(data, file, default_flow_style=False)
            print(f"Environment variables added to container '{container_name}' in '{yaml_file}'.")
        else:
            print(f"Container '{container_name}' not found in any Deployment document.")

    except FileNotFoundError:
        raise FileNotFoundError(f"Error: File '{yaml_file}' not found.")
    except Exception as e:
        raise RuntimeError(f"An error occurred: {e}") from e #Reraise with context.

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Add multiple environment variables to a Kubernetes YAML file.")
    parser.add_argument("yaml_file", help="Path to the YAML file.")
    parser.add_argument("container_name", help="Name of the container.")
    parser.add_argument("env_vars", nargs="+", help="Environment variables in 'name value' pairs.")

    args = parser.parse_args()

    if len(args.env_vars) % 2 != 0:
        print("Error: Environment variables must be provided in 'name value' pairs.")
        exit(1)

    env_vars = []
    for i in range(0, len(args.env_vars), 2):
        env_vars.append({'name': args.env_vars[i], 'value': args.env_vars[i + 1]})

    add_env_variables(args.yaml_file, args.container_name, env_vars)