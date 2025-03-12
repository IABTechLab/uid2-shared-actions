import yaml
import argparse

def add_env_variable(yaml_file, container_name, env_name, env_value):
    """
    Adds an environment variable to a specified container in a Kubernetes YAML file.

    Args:
        yaml_file (str): Path to the YAML file.
        container_name (str): Name of the container to modify.
        env_name (str): Name of the environment variable.
        env_value (str): Value of the environment variable.
    """
    try:
        with open(yaml_file, 'r') as file:
            data = list(yaml.safe_load_all(file))  # Load all documents

        modified = False  # Track if any modifications were made

        for doc in data:
            if doc and doc.get('kind') == 'Deployment':
                containers = doc['spec']['template']['spec']['containers']
                for container in containers:
                    if container['name'] == container_name:
                        if 'env' not in container:
                            container['env'] = []
                        container['env'].append({'name': env_name, 'value': env_value})
                        modified = True
                        break

        if modified:
            with open(yaml_file, 'w') as file:
                yaml.dump_all(data, file, default_flow_style=False)
            print(f"Environment variable '{env_name}' added to container '{container_name}' in '{yaml_file}'.")
        else:
            print(f"Container '{container_name}' not found in any Deployment document.")

    except FileNotFoundError:
        print(f"Error: File '{yaml_file}' not found.")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Add environment variable to a Kubernetes YAML file.")
    parser.add_argument("yaml_file", help="Path to the YAML file.")
    parser.add_argument("container_name", help="Name of the container.")
    parser.add_argument("env_name", help="Name of the environment variable.")
    parser.add_argument("env_value", help="Value of the environment variable.")

    args = parser.parse_args()

    add_env_variable(args.yaml_file, args.container_name, args.env_name, args.env_value)