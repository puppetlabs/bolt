<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->

<xsl:stylesheet version="2.0"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                exclude-result-prefixes="dita-ot xs">

<xsl:import href="plugin:org.dita.base:xsl/common/output-message.xsl"/>
<xsl:import href="plugin:org.dita.base:xsl/common/dita-utilities.xsl"/>
<xsl:import href="plugin:org.dita.base:xsl/common/dita-textonly.xsl"/>


<xsl:output indent="yes"/>

<!-- Define the error message prefix identifier -->
<!-- Deprecated since 2.3 -->
<xsl:variable name="msgprefix">DOTX</xsl:variable>

<xsl:param name="WORKDIR" select="''"/>
<xsl:param name="OUTEXT" select="'.html'"/>
<xsl:param name="DBG" select="no"/>
<xsl:variable name="work.dir">
  <xsl:choose>
    <xsl:when test="$WORKDIR and not($WORKDIR='')">
      <xsl:choose>
        <xsl:when test="not(substring($WORKDIR,string-length($WORKDIR))='/')and not(substring($WORKDIR,string-length($WORKDIR))='\')">
          <xsl:value-of select="translate($WORKDIR,
            '\/=+|?[]{}()!#$%^&amp;*__~`;:.,-abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
            '//=+|?[]{}()!#$%^&amp;*__~`;:.,-abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')"/><xsl:text>/</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="translate($WORKDIR,
            '\/=+|?[]{}()!#$%^&amp;*__~`;:.,-abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
            '//=+|?[]{}()!#$%^&amp;*__~`;:.,-abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise/>
  </xsl:choose>  
</xsl:variable>

<xsl:template match="*[contains(@class, ' map/map ')]">
  <!-- add NLS processing instruction -->
  <xsl:text>
</xsl:text><xsl:processing-instruction name="NLS"> TYPE="org.eclipse.help.toc"</xsl:processing-instruction><xsl:text>
</xsl:text>
  <toc>
    <xsl:choose>
      <xsl:when test="*[contains(@class,' topic/title ')]">
        <xsl:attribute name="label">
          <xsl:value-of select="normalize-space(*[contains(@class,' topic/title ')])"/>
        </xsl:attribute>
      </xsl:when>
      <xsl:when test="@title">
        <xsl:attribute name="label"><xsl:value-of select="@title"/></xsl:attribute>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="output-message">
          <xsl:with-param name="id" select="'DOTX002W'"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:apply-templates select="@anchorref"/>
    <!-- Add @topic to map, using the first @href in the map -->
    <xsl:if test="*[contains(@class, ' map/topicref ')][1]/descendant-or-self::*[@href]">
      <xsl:attribute name="topic">
        <xsl:apply-templates select="*[contains(@class, ' map/topicref ')][1]/descendant-or-self::*[@href][1]" mode="format-href"/>
      </xsl:attribute>
    </xsl:if>
    <xsl:apply-templates/>
  </toc>
</xsl:template>

<!-- anchorref must use forward slash, not back slash. Allow
     anchorref to a non-ditamap, but warn if the format is still dita. -->
<xsl:template match="@anchorref">
  <xsl:variable name="fix-anchorref"
    select="translate(.,
                           '\/=+|?[]{}()!#$%^&amp;*__~`;:.,-abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
                           '//=+|?[]{}()!#$%^&amp;*__~`;:.,-abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')"
    as="xs:string"/>
  <xsl:attribute name="link_to">
    <xsl:choose>
      <xsl:when test="contains($fix-anchorref,'.ditamap')">
        <!-- xsl:value-of select="$work.dir"/><xsl:text>/</xsl:text><xsl:value-of select="substring-before($fix-anchorref,'.ditamap')"/>.xml<xsl:value-of select="substring-after($fix-anchorref,'.ditamap')"/ -->
              <xsl:value-of select="$work.dir"/><xsl:value-of select="substring-before($fix-anchorref,'.ditamap')"/>.xml<xsl:value-of select="substring-after($fix-anchorref,'.ditamap')"/>
      </xsl:when>
      <xsl:when test="contains($fix-anchorref,'.xml')"><xsl:value-of select="$work.dir"/><xsl:value-of select="$fix-anchorref"/></xsl:when>
      <xsl:otherwise> <!-- should be dita, but name does not include .ditamap -->
        <!-- use the for-each so that the message scope is the map element, not the attribute -->
        <xsl:for-each select="parent::*">
          <xsl:call-template name="output-message">             
            <xsl:with-param name="id" select="'DOTX003I'"/>
            <xsl:with-param name="msgparams">%1=<xsl:value-of select="@anchorref"/></xsl:with-param>
          </xsl:call-template>
        </xsl:for-each>
        <xsl:value-of select="$work.dir"/><xsl:value-of select="$fix-anchorref"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:attribute>
</xsl:template>

<!-- Format @href for the title attribute on the map element -->
<xsl:template match="*" mode="format-href">
  <xsl:choose>
    <xsl:when test="@type='external' or (@scope='external' and not(@format)) or not(not(@format) or @format='dita')"><xsl:value-of select="@href"/></xsl:when> <!-- adding local -->
    <xsl:when test="starts-with(@href,'#')"><xsl:value-of select="@href"/></xsl:when>
    <xsl:when test="@copy-to and (not(@format) or @format = 'dita')">
      <xsl:value-of select="$work.dir"/>
      <xsl:call-template name="replace-extension">
        <xsl:with-param name="filename" select="@copy-to"/>
        <xsl:with-param name="extension" select="$OUTEXT"/>
        <xsl:with-param name="ignore-fragment" select="true()"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="@href and (not(@format) or @format = 'dita')">
      <xsl:value-of select="$work.dir"/>
      <xsl:call-template name="replace-extension">
        <xsl:with-param name="filename" select="@href"/>
        <xsl:with-param name="extension" select="$OUTEXT"/>
        <xsl:with-param name="ignore-fragment" select="true()"/>
      </xsl:call-template>
    </xsl:when>
    <!-- If it is a bad value, there will be a message when doing the real topic link -->
    <xsl:otherwise><xsl:value-of select="$work.dir"/><xsl:value-of select="@href"/></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- Make the same changes for navref/@mapref that were made for @anchorref. -->
<xsl:template match="*[contains(@class, ' map/navref ')]/@mapref">
  <xsl:variable name="fix-mapref"
    select="translate(.,
                           '\/=+|?[]{}()!#$%^&amp;*__~`;:.,-abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
                           '//=+|?[]{}()!#$%^&amp;*__~`;:.,-abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')"
    as="xs:string"/>
  <xsl:attribute name="toc">
    <xsl:choose>
      <xsl:when test="contains($fix-mapref,'.ditamap')"><xsl:value-of select="$work.dir"/><xsl:value-of select="substring-before($fix-mapref,'.ditamap')"/>.xml</xsl:when>
      <xsl:when test="contains($fix-mapref,'.xml')"><xsl:value-of select="$work.dir"/><xsl:value-of select="$fix-mapref"/></xsl:when>
      <xsl:otherwise>
        <xsl:for-each select="parent::*">
          <xsl:call-template name="output-message">
            <xsl:with-param name="id" select="'DOTX003I'"/>
            <xsl:with-param name="msgparams">%1=<xsl:value-of select="@mapref"/></xsl:with-param>
          </xsl:call-template>
        </xsl:for-each>
        <xsl:value-of select="$work.dir"/><xsl:value-of select="$fix-mapref"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:attribute>
</xsl:template>

<xsl:template match="*[contains(@class, ' map/navref ')]">
  <xsl:choose>
    <xsl:when test="@mapref">
      <link><xsl:apply-templates select="@mapref"/></link>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="output-message">
        <xsl:with-param name="id" select="'DOTX004I'"/>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="*[contains(@class, ' map/anchor ')]">
  <anchor id="{@id}"/>
</xsl:template>

<!-- If the topicref is a "topicgroup", or some other topicref that does not point
     to a file or have link text, then just move on to children. -->
<xsl:template match="*[contains(@class, ' map/topicref ')][not(@toc='no')][not(@processing-role='resource-only')]">
  <xsl:choose>
    <xsl:when test="contains(@class, ' mapgroup/topicgroup ')">
      <xsl:apply-templates/>
    </xsl:when>
    <xsl:when test="not(@href) and not(@navtitle) and not(*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]) and
                    not(*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' map/linktext ')])">
      <xsl:apply-templates/>
    </xsl:when>
    <xsl:otherwise>
    <topic>
        <xsl:attribute name="label">
          <xsl:choose>
            <xsl:when test="*[contains(@class,'- map/topicmeta ')]/*[contains(@class, '- topic/navtitle ')]">
              <xsl:apply-templates select="*[contains(@class,'- map/topicmeta ')]/*[contains(@class, '- topic/navtitle ')]" mode="dita-ot:text-only"/>
            </xsl:when>
            <xsl:when test="not(*[contains(@class,'- map/topicmeta ')]/*[contains(@class, '- topic/navtitle ')]) and @navtitle">
              <xsl:value-of select="@navtitle"/>
            </xsl:when>
            <xsl:when test="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' map/linktext ')]">
              <xsl:apply-templates select="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' map/linktext ')]" mode="dita-ot:text-only"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:choose>
                <xsl:when test="@type='external' or not(not(@format) or @format='dita')"><xsl:value-of select="@href"/></xsl:when> <!-- adding local -->
                <xsl:when test="starts-with(@href,'#')"><xsl:value-of select="@href"/></xsl:when>
                <xsl:when test="@copy-to and (not(@format) or @format = 'dita')">
                  <xsl:call-template name="replace-extension">
                    <xsl:with-param name="filename" select="@copy-to"/>
                    <xsl:with-param name="extension" select="$OUTEXT"/>
                    <xsl:with-param name="ignore-fragment" select="true()"/>
                  </xsl:call-template>
                </xsl:when>
                <xsl:when test="@href and (not(@format) or @format = 'dita')">
                  <xsl:call-template name="replace-extension">
                    <xsl:with-param name="filename" select="@href"/>
                    <xsl:with-param name="extension" select="$OUTEXT"/>
                  </xsl:call-template>
                </xsl:when>
                <xsl:when test="not(@href) or @href=''"/> <!-- P017000: error generated in prior step -->
                <xsl:otherwise>
                  <xsl:value-of select="@href"/>
                  <xsl:call-template name="output-message">
                       <xsl:with-param name="id" select="'DOTX005E'"/>
                       <xsl:with-param name="msgparams">%1=<xsl:value-of select="@href"/></xsl:with-param>
                  </xsl:call-template>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
        <xsl:if test="@href and not(@href='')">
                  <xsl:attribute name="href">
                    <xsl:choose>
                      <xsl:when test="@type='external' or (@scope='external' and not(@format)) or not(not(@format) or @format='dita')"><xsl:value-of select="@href"/></xsl:when> <!-- adding local -->
                      <xsl:when test="starts-with(@href,'#')"><xsl:value-of select="@href"/></xsl:when>
                      <xsl:when test="@copy-to and (not(@format) or @format = 'dita')">
                        <xsl:value-of select="$work.dir"/>
                        <xsl:call-template name="replace-extension">
                          <xsl:with-param name="filename" select="@copy-to"/>
                          <xsl:with-param name="extension" select="$OUTEXT"/>
                          <xsl:with-param name="ignore-fragment" select="true()"/>
                        </xsl:call-template>
                      </xsl:when>
                      <xsl:when test="@href and (not(@format) or @format = 'dita')">
                        <xsl:value-of select="$work.dir"/>
                        <xsl:call-template name="replace-extension">
                          <xsl:with-param name="filename" select="@href"/>
                          <xsl:with-param name="extension" select="$OUTEXT"/>
                        </xsl:call-template>
                      </xsl:when>
                      <xsl:otherwise>
                        <xsl:value-of select="$work.dir"/><xsl:value-of select="@href"/>
                        <xsl:call-template name="output-message">
                          <xsl:with-param name="id" select="'DOTX006E'"/>
                          <xsl:with-param name="msgparams">%1=<xsl:value-of select="@href"/></xsl:with-param>
                        </xsl:call-template>
                       </xsl:otherwise>
                     </xsl:choose>
                  </xsl:attribute>
    </xsl:if>
    <xsl:apply-templates/>
  </topic>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!--makes sure that any literal text in topicmeta does not get output as literal text in the output TOC file, which should only have text in attributes, as pulled in by the topicref template-->
<!--xsl:template match="text()">
  <xsl:apply-templates/>
</xsl:template-->
  
<xsl:template match="text()"/>

<!-- do nothing when meeting with reltable -->
<xsl:template match="*[contains(@class,' map/reltable ')]"/>

</xsl:stylesheet>
