package circuitbreaker

import (
    "sync"
    "time"
)


type CircuitBreaker struct {
	Failures         []time.Time
	FailureThreshold int
	FailureWindow    time.Duration
	State            int
	LastFailureTime  time.Time
	RetryTimeout     time.Duration
	mu               sync.Mutex
}

const (
	Closed = iota
	Open
	HalfOpen
)
