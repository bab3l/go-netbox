//go:build integration

/*
Integration tests for NetBox API client.

These tests run against a real NetBox instance and verify the API client works correctly.
Configure with environment variables:
  - NETBOX_URL: NetBox server URL (default: http://localhost:8000)
  - NETBOX_API_TOKEN: API token for authentication

Run with: go test -v ./test -tags=integration
*/

package netbox

import (
	"context"
	"os"
	"testing"

	openapiclient "github.com/bab3l/go-netbox"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// getTestClient creates an API client configured for integration testing
func getTestClient(t *testing.T) (*openapiclient.APIClient, context.Context) {
	t.Helper()

	serverURL := os.Getenv("NETBOX_URL")
	if serverURL == "" {
		serverURL = "http://localhost:8000"
	}

	apiToken := os.Getenv("NETBOX_API_TOKEN")
	if apiToken == "" {
		apiToken = "0123456789abcdef0123456789abcdef01234567"
	}

	configuration := openapiclient.NewConfiguration()
	configuration.Servers = openapiclient.ServerConfigurations{
		{URL: serverURL, Description: "NetBox Test Server"},
	}
	configuration.AddDefaultHeader("Authorization", "Token "+apiToken)

	apiClient := openapiclient.NewAPIClient(configuration)

	ctx := context.Background()
	return apiClient, ctx
}

// TestStatusAPI verifies the status endpoint works (no auth required for basic status)
func TestStatusAPI(t *testing.T) {
	client, ctx := getTestClient(t)

	resp, httpRes, err := client.StatusAPI.StatusRetrieve(ctx).Execute()

	require.NoError(t, err, "StatusRetrieve should not return an error")
	require.NotNil(t, resp, "Response should not be nil")
	assert.Equal(t, 200, httpRes.StatusCode, "Should return HTTP 200")

	// Verify response contains expected fields (status returns map[string]interface{})
	assert.Contains(t, resp, "django-version", "Django version should be present")
	assert.Contains(t, resp, "python-version", "Python version should be present")
	assert.Contains(t, resp, "netbox-version", "NetBox version should be present")

	t.Logf("NetBox version: %v", resp["netbox-version"])
	t.Logf("Django version: %v", resp["django-version"])
	t.Logf("Python version: %v", resp["python-version"])
}

// TestTenancyAPI_TenantsList verifies we can list tenants
func TestTenancyAPI_TenantsList(t *testing.T) {
	client, ctx := getTestClient(t)

	resp, httpRes, err := client.TenancyAPI.TenancyTenantsList(ctx).Execute()

	require.NoError(t, err, "TenancyTenantsList should not return an error")
	require.NotNil(t, resp, "Response should not be nil")
	assert.Equal(t, 200, httpRes.StatusCode, "Should return HTTP 200")

	t.Logf("Found %d tenants", resp.GetCount())
}

// TestDcimAPI_SitesList verifies we can list sites
func TestDcimAPI_SitesList(t *testing.T) {
	client, ctx := getTestClient(t)

	resp, httpRes, err := client.DcimAPI.DcimSitesList(ctx).Execute()

	require.NoError(t, err, "DcimSitesList should not return an error")
	require.NotNil(t, resp, "Response should not be nil")
	assert.Equal(t, 200, httpRes.StatusCode, "Should return HTTP 200")

	t.Logf("Found %d sites", resp.GetCount())
}

// TestIpamAPI_PrefixesList verifies we can list IP prefixes
func TestIpamAPI_PrefixesList(t *testing.T) {
	client, ctx := getTestClient(t)

	resp, httpRes, err := client.IpamAPI.IpamPrefixesList(ctx).Execute()

	require.NoError(t, err, "IpamPrefixesList should not return an error")
	require.NotNil(t, resp, "Response should not be nil")
	assert.Equal(t, 200, httpRes.StatusCode, "Should return HTTP 200")

	t.Logf("Found %d prefixes", resp.GetCount())
}

// TestVirtualizationAPI_ClustersList verifies we can list clusters
func TestVirtualizationAPI_ClustersList(t *testing.T) {
	client, ctx := getTestClient(t)

	resp, httpRes, err := client.VirtualizationAPI.VirtualizationClustersList(ctx).Execute()

	require.NoError(t, err, "VirtualizationClustersList should not return an error")
	require.NotNil(t, resp, "Response should not be nil")
	assert.Equal(t, 200, httpRes.StatusCode, "Should return HTTP 200")

	t.Logf("Found %d clusters", resp.GetCount())
}

// TestCircuitsAPI_CircuitsList verifies we can list circuits
func TestCircuitsAPI_CircuitsList(t *testing.T) {
	client, ctx := getTestClient(t)

	resp, httpRes, err := client.CircuitsAPI.CircuitsCircuitsList(ctx).Execute()

	require.NoError(t, err, "CircuitsCircuitsList should not return an error")
	require.NotNil(t, resp, "Response should not be nil")
	assert.Equal(t, 200, httpRes.StatusCode, "Should return HTTP 200")

	t.Logf("Found %d circuits", resp.GetCount())
}

// TestExtrasAPI_TagsList verifies we can list tags
func TestExtrasAPI_TagsList(t *testing.T) {
	client, ctx := getTestClient(t)

	resp, httpRes, err := client.ExtrasAPI.ExtrasTagsList(ctx).Execute()

	require.NoError(t, err, "ExtrasTagsList should not return an error")
	require.NotNil(t, resp, "Response should not be nil")
	assert.Equal(t, 200, httpRes.StatusCode, "Should return HTTP 200")

	t.Logf("Found %d tags", resp.GetCount())
}

// TestUsersAPI_UsersList verifies we can list users
func TestUsersAPI_UsersList(t *testing.T) {
	client, ctx := getTestClient(t)

	resp, httpRes, err := client.UsersAPI.UsersUsersList(ctx).Execute()

	require.NoError(t, err, "UsersUsersList should not return an error")
	require.NotNil(t, resp, "Response should not be nil")
	assert.Equal(t, 200, httpRes.StatusCode, "Should return HTTP 200")

	t.Logf("Found %d users", resp.GetCount())
}

// TestVpnAPI_TunnelsList verifies we can list VPN tunnels
func TestVpnAPI_TunnelsList(t *testing.T) {
	client, ctx := getTestClient(t)

	resp, httpRes, err := client.VpnAPI.VpnTunnelsList(ctx).Execute()

	require.NoError(t, err, "VpnTunnelsList should not return an error")
	require.NotNil(t, resp, "Response should not be nil")
	assert.Equal(t, 200, httpRes.StatusCode, "Should return HTTP 200")

	t.Logf("Found %d tunnels", resp.GetCount())
}

// TestWirelessAPI_WirelessLansList verifies we can list wireless LANs
func TestWirelessAPI_WirelessLansList(t *testing.T) {
	client, ctx := getTestClient(t)

	resp, httpRes, err := client.WirelessAPI.WirelessWirelessLansList(ctx).Execute()

	require.NoError(t, err, "WirelessWirelessLansList should not return an error")
	require.NotNil(t, resp, "Response should not be nil")
	assert.Equal(t, 200, httpRes.StatusCode, "Should return HTTP 200")

	t.Logf("Found %d wireless LANs", resp.GetCount())
}

// TestCoreAPI_DataSourcesList verifies we can list data sources
func TestCoreAPI_DataSourcesList(t *testing.T) {
	client, ctx := getTestClient(t)

	resp, httpRes, err := client.CoreAPI.CoreDataSourcesList(ctx).Execute()

	require.NoError(t, err, "CoreDataSourcesList should not return an error")
	require.NotNil(t, resp, "Response should not be nil")
	assert.Equal(t, 200, httpRes.StatusCode, "Should return HTTP 200")

	t.Logf("Found %d data sources", resp.GetCount())
}
