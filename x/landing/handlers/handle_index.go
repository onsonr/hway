package handlers

import (
	"github.com/labstack/echo/v4"
	"github.com/onsonr/hway/pkg/context"
	"github.com/onsonr/hway/x/landing/views"
)

func IndexHandler(c echo.Context) error {
	id := context.GetSessionID(c)
	if id == "" {
		context.NewSession(c)
	}
	return context.Render(c, views.InitialView())
}
