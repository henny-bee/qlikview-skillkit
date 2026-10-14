# Project settings (dot-sourced by every build script right after the toolkit libs). Edit for your app.
# Nav X positions are computed when omitted; keep the total width under ~850 px (the header stamp starts at x 1084).
$G = $QS.Glyph
$Global:QvAppInfo = @{
    Name  = 'My Sales App'
    Sub   = ('SALES COCKPIT  ' + $G.Mid + '  D-A-R')
    Stamp = ("='Data through ' & vDataEndDate & '   " + $G.Mid + "   all amounts in EUR'")
}
$Global:QvNav = @(
    @{ Key='DASH';  Sheet='SH_DASH';   Text='Dashboard'; W=110 },
    @{ Key='SALES'; Sheet='SH_SALES';  Text='Sales';     W=84  },
    @{ Key='CUST';  Sheet='SH_CUST';   Text='Customers'; W=100 },
    @{ Key='REP';   Sheet='SH_REPORT'; Text='Reports';   W=96  },
    @{ Key='HELP';  Sheet='SH_HELP';   Text='About';     W=84  }
)
$Global:QvSheetOrder = @($QvNav | ForEach-Object { $_.Sheet })
