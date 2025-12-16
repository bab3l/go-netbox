#!/usr/bin/env python3

import yaml

SPEC_PATH = '../api/openapi.yaml'

# Load the spec file
with open(SPEC_PATH, 'r') as file:
    data = yaml.load(file, Loader=yaml.CLoader)

# Traverse schemas
if 'components' in data and 'schemas' in data['components']:
    for component_name, schema in data['components']['schemas'].items():
        if 'properties' in schema:
            # Remove "null" item from nullable enums
            for name, prop in schema['properties'].items():
                if 'enum' in prop and None in prop['enum']:
                    prop['enum'].remove(None)
                if 'properties' in prop and 'value' in prop['properties'] and 'enum' in prop['properties']['value'] and None in prop['properties']['value']['enum']:
                    prop['properties']['value']['enum'].remove(None)

            # Fix nullable types
            nullable_types = [
                'parent_device',
                'primary_ip',
            ]

            for ntype in nullable_types:
                if ntype in schema['properties']:
                    schema['properties'][ntype]['nullable'] = True

            # Fix non-nullable types
            # See: https://github.com/OpenAPITools/openapi-generator/issues/18006
            non_nullable_types = [
                'front_image',
                'rear_image',
            ]

            for ntype in non_nullable_types:
                if ntype in schema['properties']:
                    if schema['properties'][ntype]['format'] == 'binary':
                        if 'nullable' in schema['properties'][ntype]:
                            schema['properties'][ntype].pop('nullable')

            # Make display_url, created, last_updated, and updated optional globally
            # These fields are read-only and often cause validation issues during import or when nested
            optional_fields = ['display_url', 'created', 'last_updated', 'updated']
            if 'required' in schema:
                for field in optional_fields:
                    if field in schema['required']:
                        schema['required'].remove(field)

            change_type = {
                "BriefCustomFieldChoiceSet": {
                    "choices_count": "integer"
                },
                "CustomFieldChoiceSet": {
                    "choices_count": "integer"
                }
            }

            if component_name in change_type.keys():
                for propertie in change_type[component_name].keys():
                    schema['properties'][propertie]['type'] = change_type[component_name][propertie]

            if 'required' in schema:
                non_required = {
                    "BriefManufacturer": ["devicetype_count"],
                    "BriefRIR": ["aggregate_count"],
                    "RIR": ["aggregate_count"],
                    "ASN": ["created", "last_updated", "site_count", "provider_count"],
                    "BriefRackRole": ["rack_count"],
                    "RackRole": ["rack_count"],
                    # InventoryItemRole - inventoryitem_count is computed
                    "InventoryItemRole": ["inventoryitem_count"],
                    "BriefInventoryItemRole": ["inventoryitem_count"],
                    "BriefClusterType": ["cluster_count"],
                    "ClusterType": ["cluster_count"],
                    "BriefClusterGroup": ["cluster_count"],
                    "ClusterGroup": ["cluster_count"],
                    "BriefCluster": ["virtualmachine_count"],
                    "Cluster": ["virtualmachine_count", "device_count"],
                    "VirtualMachineWithConfigContext": ["config_context"],
                    "VMInterface": ["l2vpn_termination", "count_ipaddresses", "count_fhrp_groups"],
                    "BriefDeviceRole": ["device_count", "virtualmachine_count"],
                    "DeviceRole": ["device_count", "virtualmachine_count"],
                    "BriefPlatform": ["device_count", "virtualmachine_count"],
                    "BriefVRF": ["prefix_count"],
                    "VRF": ["ipaddress_count", "prefix_count"],
                    "BriefVLANGroup": ["vlan_count", "utilization"],
                    "VLANGroup": ["vlan_count", "utilization"],
                    # Role (IPAM Role) - prefix_count and vlan_count are computed
                    "Role": ["prefix_count", "vlan_count"],
                    "VLAN": ["l2vpn_termination", "created", "last_updated", "prefix_count"],
                    "BriefRole": ["prefix_count", "vlan_count"],
                    # IPAM resources - Prefix and IP Address computed fields
                    "Prefix": ["children", "_depth"],
                    "IPAddress": [],
                    # Tenant and related models - count fields not returned on create/update
                    "Tenant": ["circuit_count", "device_count", "ipaddress_count", "prefix_count", 
                               "rack_count", "site_count", "virtualmachine_count", "vlan_count", 
                               "vrf_count", "cluster_count"],
                    "TenantGroup": ["tenant_count"],
                    "Site": ["circuit_count", "device_count", "prefix_count", "rack_count", 
                             "virtualmachine_count", "vlan_count", "display_url"],
                    "SiteGroup": ["site_count"],
                    # Manufacturer and Platform - count fields not returned on create/update
                    "Manufacturer": ["devicetype_count", "inventoryitem_count", "platform_count"],
                    "Platform": ["device_count", "virtualmachine_count"],
                    # Rack and related - count fields not returned on create/update
                    "Rack": ["device_count", "powerfeed_count"],
                    # DeviceType - count fields not returned on create/update
                    "DeviceType": ["device_count", "console_port_template_count", 
                                   "console_server_port_template_count", "power_port_template_count",
                                   "power_outlet_template_count", "interface_template_count",
                                   "front_port_template_count", "rear_port_template_count",
                                   "device_bay_template_count", "module_bay_template_count",
                                   "inventory_item_template_count"],
                    # DeviceWithConfigContext - count fields and computed fields not returned on create/update
                    "DeviceWithConfigContext": ["config_context"],
                    # Brief models - count fields not returned when nested in other responses
                    "BriefDeviceType": ["device_count"],
                    "BriefDeviceRole": ["device_count", "virtualmachine_count"],
                    "BriefSite": ["circuit_count", "device_count", "prefix_count", "rack_count", 
                                  "virtualmachine_count", "vlan_count", "display_url"],
                    "BriefRack": ["device_count"],
                    "BriefPlatform": ["device_count", "virtualmachine_count"],
                    "BriefLocation": ["rack_count", "device_count"],
                    "BriefTenant": ["circuit_count", "device_count", "ipaddress_count", "prefix_count",
                                    "rack_count", "site_count", "virtualmachine_count", "vlan_count", 
                                    "vrf_count", "cluster_count"],
                    # Interface - cable_end returns empty string when no cable is connected
                    # The OpenAPI spec marks it as required, but Netbox returns "" which fails validation
                    "Interface": ["cable_end"],
                    # Console ports, console server ports, power ports, power outlets - same cable_end issue
                    "ConsolePort": ["cable_end"],
                    "ConsoleServerPort": ["cable_end"],
                    "PowerPort": ["cable_end"],
                    "PowerOutlet": ["cable_end"],
                    "FrontPort": ["cable_end"],
                    "RearPort": ["cable_end"],
                    # Circuit terminations also have cable_end issue
                    "CircuitTermination": ["cable_end"],
                    # Circuit-related models - circuit_count is computed and not returned on create/update
                    "CircuitType": ["circuit_count"],
                    "BriefCircuitType": ["circuit_count"],
                    "Provider": ["circuit_count"],
                    "BriefProvider": ["circuit_count"],
                    "CircuitGroup": ["circuit_count"],
                    "BriefCircuitGroup": ["circuit_count"],
                    # ConfigContext - data_path/data_file/data_synced are only populated when using data source
                    "ConfigContext": ["data_path", "data_file", "data_synced"],
                    # ConfigTemplate - data_path/data_file/data_synced are only populated when using data source
                    "ConfigTemplate": ["data_path", "data_file", "data_synced"],
                    # ExportTemplate - data_path/data_file/data_synced are only populated when using data source
                    "ExportTemplate": ["data_path", "data_file", "data_synced"],
                    # PowerPanel - powerfeed_count is not returned on create
                    "PowerPanel": ["powerfeed_count"],
                    "BriefPowerPanel": ["powerfeed_count"],
                    # PowerFeed - cable_end returns empty string when no cable is connected
                    "PowerFeed": ["cable_end"],
                    # ModuleBay - device validation fails due to empty string comparison bug in generated code
                    "ModuleBay": ["device"],
                    # BriefModule - device and module_bay are not returned in all contexts (e.g., installed_module in ModuleBay)
                    "BriefModule": ["device", "module_bay"],
                    # ConfigContext - display_url is computed and causes validation issues
                    "ConfigContext": ["data_path", "data_file", "data_synced"],
                    # ASNRange - asn_count is computed and not returned on create/retrieve
                    "ASNRange": ["asn_count"],
                    # VPN models - display_url is computed and causes validation issues
                    # IKEProposal/IPSecProposal are also nested in policy responses where some fields may be omitted
                    "IKEProposal": ["display_url", "authentication_method", "encryption_algorithm", "authentication_algorithm", "group", "created", "last_updated"],
                    "IKEPolicy": ["display_url"],
                    "IPSecProposal": ["display_url", "encryption_algorithm", "authentication_algorithm", "created", "last_updated"],
                    "IPSecPolicy": ["display_url"],
                    "IPSecProfile": ["display_url"],
                    # Tunnel - terminations_count is computed and not returned on create/update
                    "Tunnel": ["terminations_count"],
                    # TunnelGroup - tunnel_count is computed and not returned on create/update
                    "TunnelGroup": ["tunnel_count"],
                    "BriefTunnelGroup": ["tunnel_count"],
                    # VirtualDeviceContext - interface_count is computed and not always returned
                    "VirtualDeviceContext": ["interface_count"],
                }

                if component_name in non_required.keys():
                    for r in non_required[component_name]:
                        if r in schema['required']:
                            schema['required'].remove(r)


# Merge Device and DeviceWithConfigContext
# We want to use DeviceWithConfigContext everywhere, but call it Device
if 'components' in data and 'schemas' in data['components']:
    if 'Device' in data['components']['schemas'] and 'DeviceWithConfigContext' in data['components']['schemas']:
        # Replace Device with DeviceWithConfigContext
        data['components']['schemas']['Device'] = data['components']['schemas']['DeviceWithConfigContext']
        # Delete DeviceWithConfigContext
        del data['components']['schemas']['DeviceWithConfigContext']
        
        # Update references
        def update_refs(obj):
            if isinstance(obj, dict):
                for k, v in obj.items():
                    if k == '$ref' and v == '#/components/schemas/DeviceWithConfigContext':
                        obj[k] = '#/components/schemas/Device'
                    else:
                        update_refs(v)
            elif isinstance(obj, list):
                for item in obj:
                    update_refs(item)
        
        update_refs(data)

# Save the spec file
with open(SPEC_PATH, 'w') as file:
    yaml.dump(data, file, Dumper=yaml.CDumper, sort_keys=False)
