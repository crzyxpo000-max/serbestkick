class_name MatchSetup
extends RefCounted
## Kariyerden gelen maç bilgisi: fikstür, takım güçleri ve hoca güveni.

var us := ""
var them := ""
var home := true
var importance := Match.Importance.LEAGUE
var our_strength := 1.0
var their_strength := 1.0
var trust := -1.0   ## 0–100; eksi = güven hesaba katılmaz
