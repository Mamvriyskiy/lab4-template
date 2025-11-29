package circuitbreaker

import (
    "time"
	"github.com/gin-gonic/gin"
)

func (cb *CircuitBreaker) addFailure() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	now := time.Now()
	cb.Failures = append(cb.Failures, now)

	cutoff := now.Add(-cb.FailureWindow)
	i := 0
	for ; i < len(cb.Failures); i++ {
		if cb.Failures[i].After(cutoff) {
			break
		}
	}
	cb.Failures = cb.Failures[i:]

	if len(cb.Failures) >= cb.FailureThreshold {
		cb.State = Open
		cb.LastFailureTime = now
	}
}

func (cb *CircuitBreaker) recordSuccess() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	cb.State = Closed
	cb.Failures = nil
}

func (cb *CircuitBreaker) Execute(
	operation func() error,
	fallback func(c *gin.Context),
	c *gin.Context,
) {
	cb.mu.Lock()

	switch cb.State {
	case Open:
		if time.Since(cb.LastFailureTime) > cb.RetryTimeout {
			cb.State = HalfOpen
		} else {
			cb.mu.Unlock()
			fallback(c)
			return
		}
	}
	cb.mu.Unlock()

	err := operation()
	if err != nil {
		cb.addFailure()
		fallback(c)
		return
	}

	cb.recordSuccess()
}
