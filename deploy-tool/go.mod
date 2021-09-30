module github.com/abetterinternet/prio-server/deploy-tool

go 1.15

require (
	cloud.google.com/go v0.97.0 // indirect
	cloud.google.com/go/secretmanager v1.0.0
	github.com/abetterinternet/prio-server/manifest-updater v0.0.0-00010101000000-000000000000
	google.golang.org/api v0.57.0
	google.golang.org/genproto v0.0.0-20210924002016-3dee208752a0
	google.golang.org/grpc v1.40.0
	k8s.io/api v0.21.3
	k8s.io/apimachinery v0.21.3
	k8s.io/client-go v0.21.3
)

replace github.com/abetterinternet/prio-server/manifest-updater => ../manifest-updater
