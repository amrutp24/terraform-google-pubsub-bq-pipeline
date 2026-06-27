package test

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"cloud.google.com/go/bigquery"
	"cloud.google.com/go/pubsub/v2"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/api/iterator"
)

func TestPubsubBqPipeline(t *testing.T) {
	t.Parallel()

	project := os.Getenv("GOOGLE_PROJECT")
	require.NotEmpty(t, project, "GOOGLE_PROJECT env var must be set")

	image := os.Getenv("TEST_IMAGE")
	require.NotEmpty(t, image, "TEST_IMAGE env var must be set (e.g. us-central1-docker.pkg.dev/project/repo/app:latest)")

	region := "us-central1"
	uniqueID := random.UniqueId()
	topicName := fmt.Sprintf("tt-topic-%s", uniqueID)
	datasetID := fmt.Sprintf("tt_events_%s", uniqueID)
	serviceName := fmt.Sprintf("tt-svc-%s", uniqueID)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "./fixtures",
		Vars: map[string]interface{}{
			"project":       project,
			"region":        region,
			"topic_name":    topicName,
			"bq_dataset_id": datasetID,
			"service_name":  serviceName,
			"image":         image,
		},
	})

	// Always destroy after the test, even on failure
	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify outputs exist
	cloudRunURL := terraform.Output(t, terraformOptions, "cloud_run_url")
	assert.NotEmpty(t, cloudRunURL, "cloud_run_url output should not be empty")

	bqDataset := terraform.Output(t, terraformOptions, "bq_dataset_id")
	assert.Equal(t, datasetID, bqDataset)

	// Publish a uniquely identifiable test message
	testMarker := fmt.Sprintf("terratest-%s", uniqueID)
	ctx := context.Background()

	pubsubClient, err := pubsub.NewClient(ctx, project)
	require.NoError(t, err, "failed to create Pub/Sub client")
	defer pubsubClient.Close()

	topic := pubsubClient.Topic(topicName)
	result := topic.Publish(ctx, &pubsub.Message{
		Data: []byte(fmt.Sprintf(`{"test":"%s","value":42}`, testMarker)),
	})
	msgID, err := result.Get(ctx)
	require.NoError(t, err, "failed to publish test message")
	t.Logf("Published message ID: %s", msgID)

	// Wait for Pub/Sub → Cloud Run → BigQuery delivery
	t.Log("Waiting 30s for message to be delivered to BigQuery...")
	time.Sleep(30 * time.Second)

	// Query BigQuery and assert the row is present
	bqClient, err := bigquery.NewClient(ctx, project)
	require.NoError(t, err, "failed to create BigQuery client")
	defer bqClient.Close()

	query := bqClient.Query(fmt.Sprintf(
		"SELECT COUNT(*) as cnt FROM `%s.%s.events` WHERE data LIKE @marker",
		project, datasetID,
	))
	query.Parameters = []bigquery.QueryParameter{
		{Name: "marker", Value: fmt.Sprintf("%%%s%%", testMarker)},
	}

	it, err := query.Read(ctx)
	require.NoError(t, err, "BigQuery query failed")

	var row []bigquery.Value
	err = it.Next(&row)
	require.NoError(t, err, "no rows returned from BigQuery query")

	count, ok := row[0].(int64)
	require.True(t, ok, "unexpected type for count column")
	assert.GreaterOrEqual(t, count, int64(1),
		"expected at least 1 row in BigQuery matching marker %s", testMarker)

	t.Logf("Found %d row(s) in BigQuery for marker %s", count, testMarker)
}
