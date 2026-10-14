# Project settings for the sales-demo example (dot-sourced by every build script right after the toolkit libs).
# Copy this file for your own app and change the name, navigation and sheet IDs.
$G = $QS.Glyph
$Global:QvAppInfo = @{
    Name  = 'CL Distribution'
    Sub   = ('SALES COCKPIT  ' + $G.Mid + '  D-A-R')
    Stamp = ("='Data through ' & vDataEndDate & '   " + $G.Mid + "   all amounts in EUR'")
}
$Global:QvNav = @(
    @{ Key='DASH';  Sheet='SH_DASH';   Text='Dashboard';            X=230; W=110 },
    @{ Key='SALES'; Sheet='SH_SALES';  Text='Sales';                X=354; W=84  },
    @{ Key='CUST';  Sheet='SH_CUST';   Text='Customers & Products'; X=442; W=170 },
    @{ Key='CN';    Sheet='SH_CN';     Text='Credit Notes';         X=616; W=116 },
    @{ Key='TEAM';  Sheet='SH_TEAM';   Text='Team & Budget';        X=736; W=126 },
    @{ Key='REP';   Sheet='SH_REPORT'; Text='Reports';              X=876; W=96  },
    @{ Key='HELP';  Sheet='SH_HELP';   Text='About';                X=986; W=84  }
)
$Global:QvSheetOrder = @($QvNav | ForEach-Object { $_.Sheet })
