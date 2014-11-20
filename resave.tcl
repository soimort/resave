#!/usr/bin/env tclsh
package require http
package require tls
package require autoproxy

set script_name resave
set version 0.0.1
set usage {Resave, a web scraping resource downloader.
Usage: resave [OPTION]... [URL]...

Mandatory arguments to long options are mandatory for short options too.

Options:
  -V,  --version           display the version and exit.
  -h,  --help              print this help.

  -r,  --resource          download resource if supported (default).
  -b,  --bookmark          save as bookmark.
  -o,  --output [OUT_DIR]  save files to OUT_DIR/...
  -q,  --quiet             quiet (no output).
}

# Optional args
set optargs {
    resource  1
    quiet     0
}

# Legitimize filename
proc legitimize {filename} {
    string map -nocase {
        "/" "-"
        "\n" " "
    } [string range $filename 0 100]
}

################
# Sub-commands #
################

# Print version
proc version {} {
    global script_name version
    puts stdout "$script_name $version"
}

# Print help
proc help {} {
    global usage
    puts stdout $usage
}

# Save URL as HTML bookmark
proc save_url {url} {
    global optargs
    if {[dict exists $optargs output]} {
        set output [dict get $optargs output]
    } else {
        set output {}
    }

    regexp {^([[:alpha:]]+)://} $url -> protocol
    if {[string equal $protocol https]} {
        ::http::register https 443 ::tls::socket
    }

    regexp {^[[:alpha:]]+://([^/]+)} $url -> domain
    set token [http::geturl $url]
    set data [http::data $token]
    regexp {(?i)<title>([^<]+)} $data -> title
    set filename "$title - $domain"
    http::cleanup $token

    set filename [legitimize $filename]
    set filename [file join $output $filename]

    if {[file exists "$filename.html"]} {
        for {set i 1} {[file exists "$filename ($i).html"]} {incr i} {}
        set filename "$filename ($i)"
    }
    set filename "$filename.html"

    set html "<meta http-equiv=\"refresh\" content=\"0; $url\">"

    set ofid [open $filename w]
    puts -nonewline $ofid $html
    close $ofid
}

# Save images
proc save_images {url} {
    global optargs
    set quiet [dict get $optargs quiet]
    if {[dict exists $optargs output]} {
        set output [dict get $optargs output]
    } else {
        set output {}
    }

    http::register https 443 [list ::tls::socket -ssl2 0 -ssl3 0 -tls1 1]

    regexp {^[[:alpha:]]+://([^/]+)} $url -> domain
    set token [http::geturl $url]
    set data [http::data $token]
    http::cleanup $token

    regexp {<title>([^<]+)</title>} $data -> title
    set title [string trim $title]

    set matches [regexp -all -inline {https?:[^\"\')]+(\.jpg|\.png|\.gif)} $data]
    set len [expr [llength $matches] / 2]
    set i 0
    foreach {imgUrl _} $matches {
        incr i
        set dirname "$title - $domain"

        set dirname [legitimize $dirname]
        set dirname [file join $output $dirname]

        if {![file isdirectory $dirname]} {
            file mkdir $dirname
        }

        regexp {/([^/]+)$} $imgUrl -> output_filename
        set output_filename "\[$i\] $output_filename"

        set output_filename [legitimize $output_filename]
        if {[file exists [file join $dirname $output_filename]]} {
            if {!$quiet} { puts "\[Skipping $i/$len\] $imgUrl" }
        } else {
            if {!$quiet} { puts "\[Downloading $i/$len\] $imgUrl" }

            # Download $imgUrl
            set filename [file join $dirname $output_filename]
            set ofid [open $filename w]
            chan configure $ofid -translation binary
            set token [http::geturl $imgUrl -channel $ofid]
            http::cleanup $token
            close $ofid
        }
    }
}

# Save images from Ameblo
proc save_ameblo {url} {
    global optargs
    set quiet [dict get $optargs quiet]
    if {[dict exists $optargs output]} {
        set output [dict get $optargs output]
    } else {
        set output {}
    }

    regexp {^[[:alpha:]]+://([^/]+)} $url -> domain
    set token [http::geturl $url]
    set data [http::data $token]
    http::cleanup $token

    regexp {(?i)<title>([^<]+)} $data -> title
    set matches [regexp -all -inline {(http://stat.ameba.jp/user_images/[^\"<]+)} $data]
    set len [expr [llength $matches] / 2]
    set i 0
    foreach {_ imgUrl} $matches {
        incr i
        set dirname "$title - $domain"

        set dirname [legitimize $dirname]
        set dirname [file join $output $dirname]

        if {![file isdirectory $dirname]} {
            file mkdir $dirname
        }

        regexp {/([^/]+)$} $imgUrl -> output_filename
        set output_filename [legitimize $output_filename]
        if {[file exists [file join $dirname $output_filename]]} {
            if {!$quiet} { puts "\[Skipping $i/$len\] $imgUrl" }
        } else {
            if {!$quiet} { puts "\[Downloading $i/$len\] $imgUrl" }

            # Download $imgUrl
            set filename [file join $dirname $output_filename]
            set ofid [open $filename w]
            chan configure $ofid -translation binary
            set token [http::geturl $imgUrl -channel $ofid]
            http::cleanup $token
            close $ofid
        }
    }

    set matches [regexp -all -inline {"imgUrl":"([^\"]+)"[^\{]+"title":"([^\"]+)"} $data]
    set len [expr [llength $matches] / 3]
    set i 0
    foreach {_ imgUrl title} $matches {
        incr i
        set dirname "$title - $domain"

        set dirname [legitimize $dirname]
        set dirname [file join $output $dirname]

        if {![file isdirectory $dirname]} {
            file mkdir $dirname
        }

        set imgUrl "http://stat.ameba.jp$imgUrl"

        regexp {/([^/]+)$} $imgUrl -> output_filename
        set output_filename [legitimize $output_filename]
        if {[file exists [file join $dirname $output_filename]]} {
            if {!$quiet} { puts "\[Skipping $i/$len\] $imgUrl" }
        } else {
            if {!$quiet} { puts "\[Downloading $i/$len\] $imgUrl" }

            # Download $imgUrl
            set filename [file join $dirname $output_filename]
            set ofid [open $filename w]
            chan configure $ofid -translation binary
            set token [http::geturl $imgUrl -channel $ofid]
            http::cleanup $token
            close $ofid
        }
    }
}

# Save images from Instagram
proc save_instagram {url} {
    global optargs
    if {[dict exists $optargs output]} {
        set output [dict get $optargs output]
    } else {
        set output {}
    }

    set token [http::geturl $url]
    set data [http::data $token]
    http::cleanup $token

    regexp {(?i)<meta property="og:image" content="([^\"]+)"} $data -> imgUrl
    regexp {(?i)<meta property="og:title" content="([^\"]+)"} $data -> title
    if {[info exists title]} {
        set output_filename $title.jpg
    } else {
        regexp {/([^/]+)$} $imgUrl -> output_filename
    }
    set output_filename [legitimize $output_filename]

    # Download $imgUrl
    set filename [file join $output $output_filename]
    set ofid [open $filename w]
    chan configure $ofid -translation binary
    set token [http::geturl $imgUrl -channel $ofid]
    http::cleanup $token
    close $ofid
}

# Save images from Baidu Tieba
proc save_baidu_tieba {url} {
    global optargs
    set quiet [dict get $optargs quiet]
    if {[dict exists $optargs output]} {
        set output [dict get $optargs output]
    } else {
        set output {}
    }

    regexp {^[[:alpha:]]+://([^/]+)} $url -> domain
    set token [http::geturl $url]
    set data [http::data $token]
    http::cleanup $token

    regexp {(?i)<title>([^<]+)} $data -> title

    set matches [regexp -all -inline {class="BDE_Image"[^<>]+src="([^\"]+)"} $data]
    set matches [concat $matches [regexp -all -inline {src="([^\"]+)"[^<>]+class="BDE_Image"} $data]]
    set matches [concat $matches [regexp -all -inline {src="([^\"]+)"[^<>]+class="BDE_Image"} $data]]
    set len [expr [llength $matches] / 2]
    set i 0
    foreach {_ imgUrl} $matches {
        incr i
        set dirname "$title - $domain"

        set dirname [legitimize $dirname]
        set dirname [file join $output $dirname]

        if {![file isdirectory $dirname]} {
            file mkdir $dirname
        }

        regexp {/([^/]+)$} $imgUrl -> output_filename
        set output_filename [legitimize $output_filename]
        if {[file exists [file join $dirname $output_filename]]} {
            if {!$quiet} { puts "\[Skipping $i/$len\] $imgUrl" }
        } else {
            # Set new $imgUrl
            set imgUrl http://imgsrc.baidu.com/forum/pic/item/$output_filename

            if {!$quiet} { puts "\[Downloading $i/$len\] $imgUrl" }

            # Download $imgUrl
            set filename [file join $dirname $output_filename]
            set ofid [open $filename w]
            chan configure $ofid -translation binary
            set token [http::geturl $imgUrl -channel $ofid]
            http::cleanup $token
            close $ofid
        }
    }
}

# Save images from Douban
proc save_douban {url} {
    global optargs
    set quiet [dict get $optargs quiet]
    if {[dict exists $optargs output]} {
        set output [dict get $optargs output]
    } else {
        set output {}
    }

    regexp {^[[:alpha:]]+://([^/]+)} $url -> domain
    set token [http::geturl $url]
    set data [http::data $token]
    http::cleanup $token

    regexp {(?i)<title>([^<]+)} $data -> title
    set title [string trim $title]

    set matches [regexp -all -inline {id="[^\"]+"><img src="([^\"]+)"} $data]
    set len [expr [llength $matches] / 2]
    set i 0
    foreach {_ imgUrl} $matches {
        incr i
        set dirname "$title - $domain"

        set dirname [legitimize $dirname]
        set dirname [file join $output $dirname]

        if {![file isdirectory $dirname]} {
            file mkdir $dirname
        }

        regexp {/([^/]+)$} $imgUrl -> output_filename

        # Set new $imgUrl
        set imgUrl [lindex [regexp -all -inline (.+/view/photo/) $imgUrl] 1]photo/public/$output_filename

        set output_filename [legitimize $output_filename]
        if {[file exists [file join $dirname $output_filename]]} {
            if {!$quiet} { puts "\[Skipping $i/$len\] $imgUrl" }
        } else {
            if {!$quiet} { puts "\[Downloading $i/$len\] $imgUrl" }

            # Download $imgUrl
            set filename [file join $dirname $output_filename]
            set ofid [open $filename w]
            chan configure $ofid -translation binary
            set token [http::geturl $imgUrl -channel $ofid]
            http::cleanup $token
            close $ofid
        }
    }
}

# Save images from Tumblr
proc save_tumblr {url} {
    global optargs
    set quiet [dict get $optargs quiet]
    if {[dict exists $optargs output]} {
        set output [dict get $optargs output]
    } else {
        set output {}
    }

    http::register https 443 [list ::tls::socket -ssl2 0 -ssl3 0 -tls1 1]

    regexp {^[[:alpha:]]+://([^/]+)} $url -> domain
    set token [http::geturl $url]
    set data [http::data $token]
    http::cleanup $token

    regexp {<meta property="og:description" content="([^\"]+)"} $data -> title
    if {[info exists title] == 0} {
        regexp {<meta name="keywords" content="([^\"]+)"} $data -> title
    }
    if {[info exists title] == 0} {
        regexp {<title>([^<]+)</title>} $data -> title
    }
    set title [string trim $title]

    set matches [regexp -all -inline {<meta property="og:image" content="([^\"]+)"} $data]
    set len [expr [llength $matches] / 2]
    set i 0
    foreach {_ imgUrl} $matches {
        incr i
        set dirname "$title - $domain"

        set dirname [legitimize $dirname]
        set dirname [file join $output $dirname]

        if {![file isdirectory $dirname]} {
            file mkdir $dirname
        }

        regexp {/([^/]+)$} $imgUrl -> output_filename

        set output_filename [legitimize $output_filename]
        if {[file exists [file join $dirname $output_filename]]} {
            if {!$quiet} { puts "\[Skipping $i/$len\] $imgUrl" }
        } else {
            if {!$quiet} { puts "\[Downloading $i/$len\] $imgUrl" }

            # Download $imgUrl
            set filename [file join $dirname $output_filename]
            set ofid [open $filename w]
            chan configure $ofid -translation binary
            set token [http::geturl $imgUrl -channel $ofid]
            http::cleanup $token
            close $ofid
        }
    }
}

# Save images from Google+ album
proc save_google_plus {url} {
    global optargs
    set quiet [dict get $optargs quiet]
    if {[dict exists $optargs output]} {
        set output [dict get $optargs output]
    } else {
        set output {}
    }

    http::register https 443 ::autoproxy::tls_socket

    regexp {^[[:alpha:]]+://([^/]+)} $url -> domain
    set token [http::geturl $url]
    set data [http::data $token]
    http::cleanup $token

    regexp {<title[^<]+>(.+)</title>} $data -> title
    if {![info exists title]} {
        regexp {The document has moved <A HREF="([^\"]+)">here} $data -> new_url
        set token [http::geturl $new_url]
        set data [http::data $token]
        http::cleanup $token
        regexp {<title[^<]+>(.+)</title>} $data -> title
        puts $title
    }
    set title [string trim $title]

    set matches [regexp -all -inline {(https://lh[[:digit:]].googleusercontent.com/[^/\"]+)\"} $data]
    set len [expr [llength $matches] / 2]
    set i 0
    foreach {_ imgUrl} $matches {
        incr i
        set dirname "$title - $domain"

        set dirname [legitimize $dirname]
        set dirname [file join $output $dirname]

        if {![file isdirectory $dirname]} {
            file mkdir $dirname
        }

        regexp {/([^/]+)$} $imgUrl -> output_filename

        set output_filename [legitimize $output_filename]
        if {[file exists [file join $dirname $output_filename]]} {
            if {!$quiet} { puts "\[Skipping $i/$len\] $imgUrl" }
        } else {
            if {!$quiet} { puts "\[Downloading $i/$len\] $imgUrl" }

            # Download $imgUrl
            set filename [file join $dirname $output_filename]
            set ofid [open $filename w]
            chan configure $ofid -translation binary
            set token [http::geturl $imgUrl=s0 -channel $ofid]
            http::cleanup $token
            close $ofid
        }
    }
}

# Save images from Twitter
proc save_twitter {url} {
    global optargs
    set quiet [dict get $optargs quiet]
    if {[dict exists $optargs output]} {
        set output [dict get $optargs output]
    } else {
        set output {}
    }

    http::register https 443 [list ::tls::socket -ssl2 0 -ssl3 0 -tls1 1]

    regexp {^[[:alpha:]]+://([^/]+)} $url -> domain
    set token [http::geturl $url]
    set data [http::data $token]
    http::cleanup $token

    regexp {http://t.co/([^&]+)&} $data -> title

    set matches [regexp -all -inline {"(https://pbs.twimg.com/media/[^:\"]+)"} $data]
    set len [expr [llength $matches] / 2]
    set i 0
    foreach {_ imgUrl} $matches {
        incr i
        set dirname "."

        set imgUrl $imgUrl:orig
        regexp {/([^/]+)$} $imgUrl -> output_filename

        set output_filename [legitimize $output_filename]
        if {[file exists [file join $dirname $output_filename]]} {
            if {!$quiet} { puts "\[Skipping $i/$len\] $imgUrl" }
        } else {
            if {!$quiet} { puts "\[Downloading $i/$len\] $imgUrl" }

            # Download $imgUrl
            set filename [file join $dirname $output_filename]
            set ofid [open $filename w]
            chan configure $ofid -translation binary
            set token [http::geturl $imgUrl -channel $ofid]
            http::cleanup $token
            close $ofid
        }
    }
}

# Save main
proc save {url} {
    global optargs
    set resource [dict get $optargs resource]

    regexp {^([[:alpha:]]+)://} $url -> protocol
    if {[info exists protocol]} {
        if {![string equal $protocol "http"]
            && ![string equal $protocol "https"]} {
            puts "Unsupported protocol"
            return
        }
    } else {
        set url http://$url
    }

    if {$resource == 0} {
        save_url $url
    } else {
        if {[string match "http://ameblo.jp/*" $url]} {
            save_ameblo $url
        } elseif {[string match "http://instagram.com/*" $url]} {
            save_instagram $url
        } elseif {[string match "http://tieba.baidu.com/*" $url]} {
            save_baidu_tieba $url
        } elseif {[string match "http://site.douban.com/*" $url]} {
            save_douban $url
        } elseif {[string match "http://*.tumblr.com/*" $url]} {
            save_tumblr $url
        } elseif {[string match "https://plus.google.com/*" $url]} {
            save_google_plus $url
        } elseif {[string match "https://twitter.com/*" $url]} {
            save_twitter $url
        } else {
            save_images $url
        }
    }
}

################
# Main program #
################

# Print help if no argument is given
if {$argc == 0} { help; exit }

# Parse command-line options
if {[string equal [info script] $argv0]} {
    while {[llength $argv] > 0} {
        set flag [lindex $argv 0]
        switch -regexp -- $flag {
            "^(-V|--version)$" {
                # Print version
                version; exit
            }

            "^(-h|--help)$" {
                # Print help
                help; exit
            }

            "^(-r|--resource)$" {
                # Resource mode
                set argv [lrange $argv 1 end]
                dict set optargs resource 1
            }

            "^(-b|--bookmark)$" {
                # Bookmark mode
                set argv [lrange $argv 1 end]
                dict set optargs resource 0
            }

            "^(-q|--quiet)$" {
                # Quiet mode
                set argv [lrange $argv 1 end]
                dict set optargs quiet 1
            }

            "^(-o|--output)$" {
                # Output folder
                set value [lindex $argv 1]
                set argv [lrange $argv 2 end]
                dict set optargs output $value
            }
            "^(-o.+)$" {
                # Output folder
                regexp -- {-o(.+)} $flag _ value
                set argv [lrange $argv 1 end]
                dict set optargs output $value
            }

            default {
                # End of options
                break
            }
        }
    }
}

autoproxy::init

foreach url $argv {
    save $url
}

exit
