<xsl:stylesheet version="1.0"
            xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
            xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
            xmlns:u="urn:schemas-microsoft-com:unattend">

  <xsl:output method="xml" indent="yes" encoding="utf-8" omit-xml-declaration="yes" doctype-system="about:legacy-compat"/>

  <xsl:strip-space elements="*"/>

  <xsl:param name="WindowsVersion" />
  <xsl:param name="ProductKey" />
  <xsl:param name="ProcessorArchitecture" />
  <xsl:param name="ImageName" />
  <xsl:param name="Firmware" />
  <xsl:param name="ImageProvisioner" />
  <xsl:param name="WinRmUsername" />
  <xsl:param name="WinRmPassword" />
  <xsl:param name="Locale" />

  <!-- 
    Global Replace String Substitute Function used later in the transforms
    From: https://stackoverflow.com/questions/47821701/xslt-to-find-and-replace-attributes-while-retaining-the-rest-of-the-tag
  -->
  <xsl:template name="globalReplace">
      <xsl:param name="param.str"/>
      <xsl:param name="param.target"/>
      <xsl:param name="param.replacement"/>
      <xsl:choose>
          <xsl:when test="contains($param.str, $param.target)">
              <xsl:value-of select="concat(substring-before($param.str, $param.target), $param.replacement, substring-after($param.str, $param.target))"/>
          </xsl:when>
          <xsl:otherwise>
              <xsl:value-of select="$param.str"/>
          </xsl:otherwise>
      </xsl:choose>
  </xsl:template>

  <!-- General match everything unless matched by more specific rules below -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- Pass all comments through to the output -->
  <xsl:template match="comment()">
    <xsl:copy />
  </xsl:template>

  <!-- Some logic to set the correct OSDriverPlatform variable so we can choose correct PE drivers to load -->
  <xsl:variable name="OSDriverPlatform">
    <xsl:choose>
      <xsl:when test="$WindowsVersion = 'Windows-2008' or $WindowsVersion = 'Windows-2008r2' or $WindowsVersion = 'Windows-7' " >
        <xsl:value-of select="'Vista'" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="'Win8'" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- Choose correct process architecture (32/64 bit) -->
  <xsl:template match='u:unattend/u:settings/u:component'>
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:attribute name="processorArchitecture">
        <xsl:value-of select="$ProcessorArchitecture"/>
      </xsl:attribute>
      <xsl:apply-templates select="node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- Rule to select correct driver paths for PE phase -->
  <xsl:template match='u:unattend/u:settings/u:component[@name="Microsoft-Windows-PnpCustomizationsWinPE"]/u:DriverPaths/u:PackerDriversVersion |
                       u:unattend/u:settings/u:component[@name="Microsoft-Windows-PnpCustomizationsNonWinPE"]/u:DriverPaths/u:PackerDriversVersion'>
      <xsl:if test="@OSDriverPlatform=$OSDriverPlatform">
        <xsl:copy-of select="node()" />
      </xsl:if>
  </xsl:template>

  <!-- Rule to select disk configuration -->
  <xsl:template match='u:unattend/u:settings/u:component[@name="Microsoft-Windows-Setup"]/u:PackerDiskConfiguration'>
       <xsl:if test="(@Firmware=$Firmware) and (@ImageProvisioner=$ImageProvisioner)">
          <!-- Strip out PackerDiskConfiguration once selected to present valid Unattend.xml -->
          <xsl:copy-of select="node()" />
       </xsl:if>
  </xsl:template>

  <!-- Install Image to correct Partition depending on ImageProvisioner/Firmware -->
  <xsl:template match='u:unattend/u:settings/u:component[@name="Microsoft-Windows-Setup"]/u:ImageInstall/u:OSImage/u:InstallTo/u:PartitionID'>
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:choose>
        <xsl:when test="($Firmware='bios') and ($ImageProvisioner='vmware')">
          <xsl:value-of select="1"/>
        </xsl:when>
        <xsl:when test="($Firmware='efi') and ($ImageProvisioner='virtualbox')">
          <xsl:value-of select="2"/>
        </xsl:when>
        <xsl:otherwise>
           <xsl:value-of select="3"/> 
        </xsl:otherwise>
     </xsl:choose>
    </xsl:copy>
  </xsl:template>

  <!-- Rule to select appropriate logon sequence and perform Administrator/Password substitutions by applying further templates -->
  <xsl:template match='u:unattend/u:settings/u:component[@name="Microsoft-Windows-Shell-Setup"]/u:FirstLogonCommands'>
    <xsl:if test="@ImageProvisioner=$ImageProvisioner">
      <!-- Strip out attributes and just present node as is -->
      <xsl:copy>
        <xsl:apply-templates select="*" />
      </xsl:copy>
    </xsl:if>
  </xsl:template>

  <!-- 
    "sub" Rule associated with above rule to add more specific processing for SynchronousCommand 
    Switches mode to EditCommandLine for children of this element.
  -->
  <xsl:template match='u:SynchronousCommand'>
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates select="node()" mode="EditCommandLine" />
    </xsl:copy>
  </xsl:template>

  <!-- "sub" Rule to Match all for Synchronous commands -->
  <xsl:template match='@*|node()' mode='EditCommandLine'>
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- 
    "sub" Rule to edit the CommandLine Element to insert correct Admin Username and Password 
    Use two passes of the global replace function to translate each.
    -->
  <xsl:template match='u:CommandLine' mode='EditCommandLine'>
    <xsl:variable name="CmdStr_B">
      <xsl:call-template name="globalReplace">
          <xsl:with-param name="param.str" select="."/>
          <xsl:with-param name="param.target" select="'__ADMIN_USERNAME__'" />
          <xsl:with-param name="param.replacement" select="$WinRmUsername"/> 
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="CmdStr_Final">
      <xsl:call-template name="globalReplace">
          <xsl:with-param name="param.str" select="$CmdStr_B"/>
          <xsl:with-param name="param.target" select="'__ADMIN_PASSWORD__'" />
          <xsl:with-param name="param.replacement" select="$WinRmPassword"/> 
      </xsl:call-template>
    </xsl:variable>
    <xsl:copy>
      <xsl:value-of select="$CmdStr_Final" />
    </xsl:copy>
  </xsl:template>
  <!-- End of "sub" Rules -->

  <!-- Rule to replace image name -->
  <xsl:template match='u:unattend/u:settings/u:component[@name="Microsoft-Windows-Setup"]/u:ImageInstall/u:OSImage/u:InstallFrom/u:MetaData/u:Value'>
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:value-of select="$ImageName"/>
    </xsl:copy>
  </xsl:template>

  <!-- Rule to replace product key -->
  <xsl:template match='u:unattend/u:settings/u:component[@name="Microsoft-Windows-Setup"]/u:UserData/u:ProductKey/u:Key |
                       u:unattend/u:settings/u:component[@name="Microsoft-Windows-Shell-Setup"]/u:ProductKey'>
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:value-of select="$ProductKey"/>
    </xsl:copy>
  </xsl:template>

  <!-- Strip out these components and elements for Windows-2008 only -->
  <xsl:template match='u:unattend/u:settings/u:component[@name="Microsoft-Windows-Security-SPP-UX"] | 
                      u:unattend/u:settings/u:component[@name="Microsoft-Windows-LUA-Settings"] |
                      u:unattend/u:settings/u:component[@name="Microsoft-Windows-Security-SPP"] |
                      u:unattend/u:settings/u:component[@name="Microsoft-Windows-Shell-Setup"]/u:OOBE/u:HideWirelessSetupInOOBE'>
    <xsl:if test="not($WindowsVersion = 'Windows-2008')">
      <xsl:copy>
        <xsl:apply-templates select="@*|node()"/>
      </xsl:copy>
    </xsl:if>
  </xsl:template>

  <!-- Pick up the correct local for Internationalisation -->
  <xsl:template match='u:unattend/u:settings/u:component/u:SetupUILanguage/u:UILanguage |
                       u:unattend/u:settings/u:component/u:InputLocale |
                       u:unattend/u:settings/u:component/u:SystemLocale |
                       u:unattend/u:settings/u:component/u:UILanguage |
                       u:unattend/u:settings/u:component/u:UserLocale'>
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:value-of select="$Locale"/>
    </xsl:copy>
  </xsl:template>

  <!-- These components ane elements are only appropriate for Servers, so filter out for Desktop Versions -->
  <xsl:template match='u:unattend/u:settings/u:component[@name="Microsoft-Windows-ServerManager-SvrMgrNc"] | 
                      u:unattend/u:settings/u:component[@name="Microsoft-Windows-IE-ESC"] |
                      u:unattend/u:settings/u:component[@name="Microsoft-Windows-Shell-Setup"]/u:ShowWindowsLive '>
    <xsl:choose>
      <xsl:when test="$WindowsVersion = 'Windows-7'" />
      <xsl:when test="$WindowsVersion = 'Windows-8.1'" />
      <xsl:when test="$WindowsVersion = 'Windows-10'" />
      <xsl:otherwise>
        <xsl:copy>
          <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Windows-10 and Windows-8.1 & 7 Need this component added -->
  <xsl:template match='u:unattend/u:settings/u:component[@name="Microsoft-Windows-Deployment"]'>
    <xsl:if test="($WindowsVersion='Windows-7') or ($WindowsVersion='Windows-8.1') or ($WindowsVersion='Windows-10')" >
      <xsl:copy>
        <xsl:apply-templates select="@*|node()"/>
      </xsl:copy>
    </xsl:if>
  </xsl:template>

  <xsl:template match='u:unattend/u:settings/u:component[@name="Microsoft-Windows-Shell-Setup"]/u:OOBE/u:NetworkLocation'>
    <xsl:if test="not($WindowsVersion = 'Windows-10')">
      <xsl:copy>
        <xsl:apply-templates select="@*|node()"/>
      </xsl:copy>
    </xsl:if>
  </xsl:template> 

  <!-- Windows 7 Needs Timezone set in the OOBE phase too -->
  <xsl:template match='u:unattend/u:settings[@pass="oobeSystem"]/u:component[@name="Microsoft-Windows-Shell-Setup"]/u:TimeZone'>
    <xsl:if test="$WindowsVersion = 'Windows-7'">
      <xsl:copy>
        <xsl:apply-templates select="@*|node()"/>
      </xsl:copy>
    </xsl:if>
  </xsl:template> 

  <!-- Select correct OOBE elements depending on OS Version -->
  <xsl:template match='u:unattend/u:settings/u:component[@name="Microsoft-Windows-Shell-Setup"]/u:OOBE/u:HideOnlineAccountScreens | 
                       u:unattend/u:settings/u:component[@name="Microsoft-Windows-Shell-Setup"]/u:OOBE/u:HideLocalAccountScreen | 
                       u:unattend/u:settings/u:component[@name="Microsoft-Windows-Shell-Setup"]/u:OOBE/u:HideOEMRegistrationScreen'>
    <xsl:choose>
      <xsl:when test="$WindowsVersion = 'Windows-2008'" />
      <xsl:when test="$WindowsVersion = 'Windows-2008r2'" />
      <xsl:when test="$WindowsVersion = 'Windows-7'" />
      <xsl:otherwise>
        <!-- 
            Copy Elements for these Operating Systems.
            Windows-2012r2
            Windows-2016
            Windows-2012
            Windows-8.1
            Windows-10 (except exception above for Network/work)
          -->
        <xsl:copy>
          <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Insert correct Administrator Password -->
  <xsl:template match='u:unattend/u:settings/u:component[@name="Microsoft-Windows-Shell-Setup"]/u:UserAccounts/u:AdministratorPassword/u:Value |
                       u:unattend/u:settings/u:component[@name="Microsoft-Windows-Shell-Setup"]/u:UserAccounts/u:LocalAccounts/u:LocalAccount/u:Password/u:Value | 
                       u:unattend/u:settings/u:component[@name="Microsoft-Windows-Shell-Setup"]/u:AutoLogon/u:Password/u:Value'>
    <xsl:copy>
      <xsl:value-of select="$WinRmPassword"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match='u:unattend/u:settings/u:component[@name="Microsoft-Windows-Shell-Setup"]/u:UserAccounts/u:LocalAccounts/u:LocalAccount/u:Name |
                       u:unattend/u:settings/u:component[@name="Microsoft-Windows-Shell-Setup"]/u:UserAccounts/u:LocalAccounts/u:LocalAccount/u:DisplayName |
                       u:unattend/u:settings/u:component[@name="Microsoft-Windows-Shell-Setup"]/u:AutoLogon/u:Username'>
    <xsl:copy>
      <xsl:value-of select="$WinRmUsername"/>
    </xsl:copy>
  </xsl:template>

  <!-- Here endeth the transform -->
</xsl:stylesheet>
