package main

import (
	"time"

	"code.cloudfoundry.org/lager"

	"github.com/alphagov/paas/tools/metrics/pkg/billing"
	m "github.com/alphagov/paas/tools/metrics/pkg/metrics"
)

func BillingCostsGauge(
	logger lager.Logger,
	endpoint string,
	interval time.Duration,
) m.MetricReadCloser {
	return m.NewMetricPoller(interval, func(w m.MetricWriter) error {
		lsession := logger.Session("billing-gauges")
		billing := billing.NewClient(endpoint, lsession)

		plans, err := billing.GetPlans()
		if err != nil {
			lsession.Error("Failed to get billing plans", err)
			return err
		}

		costs, err := billing.GetCostsByPlan()
		if err != nil {
			lsession.Error("Failed to get billing costs metrics", err)
			return err
		}

		rates, err := billing.GetLatestCurrencyRates()
		if err != nil {
			lsession.Error("Failed to get latest currency rates", err)
			return err
		}

		metrics := CostsByPlanGauges(costs, plans)
		metrics = append(metrics, CurrencyRateGauges(rates)...)

		lsession.Info("Writing billing metrics")
		return w.WriteMetrics(metrics)
	})
}

func CostsByPlanGauges(
	totalCosts []billing.CostByPlan,
	plans []billing.Plan,
) []m.Metric {
	metrics := make([]m.Metric, 0)

	plansMapping := make(map[string]string, 0)
	for _, plan := range plans {
		plansMapping[plan.PlanGUID] = plan.Name
	}

	for _, plan := range totalCosts {
		metrics = append(metrics, m.Metric{
			Kind:  m.Gauge,
			Time:  time.Now(),
			Name:  "billing.total.costs",
			Value: plan.Cost,
			Tags: m.MetricTags{
				m.MetricTag{Label: "plan_guid", Value: plan.PlanGUID},
				m.MetricTag{Label: "name", Value: plansMapping[plan.PlanGUID]},
			},
			Unit: "pounds",
		})
	}

	return metrics
}

func CurrencyRateGauges(
	rates []billing.CurrencyRate,
) []m.Metric {
	metrics := make([]m.Metric, 0)

	for _, rate := range rates {
		metrics = append(metrics, m.Metric{
			Kind:  m.Gauge,
			Time:  time.Now(),
			Name:  "billing.currency.configured",
			Value: rate.Rate,
			Tags: m.MetricTags{
				m.MetricTag{Label: "code", Value: rate.Code},
			},
			Unit: "ratio",
		})
	}

	return metrics
}
