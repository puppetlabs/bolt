<!-- 
This file is part of the DITA Open Toolkit project.

Copyright 2007 Shawn McKenzie

See the accompanying LICENSE file for applicable license.
-->
<!--
  UPDATES:
  20110817 RDA Include several fixes:
      * Make several element tests specialization aware
      * Topichead with navtitle element and navtitle attribute
        duplicates the branch underneath
      * Topicref with no href or title drops the branch
      * Toc=no drops any nested toc=yes branches (unlike XHTML / others)
  *-->
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:variable name="quote">"</xsl:variable>
  <xsl:variable name="quotestring">\"</xsl:variable>
  <xsl:variable name="lessthan">&lt;</xsl:variable>
  <xsl:variable name="lessthanstring">&amp;lt;</xsl:variable>

  <xsl:template match="*[contains(@class, ' map/topicref ')]">
    <xsl:param name="parent"/>
    <xsl:param name="contentwin"/>

<!--    <xsl:message>
####### In map/topicref for <xsl:value-of select="@href"/>, $contentwin is set to: <xsl:value-of select="$contentwin"/>     
    </xsl:message>-->
    
    <xsl:variable name="apos">'</xsl:variable>
    <xsl:variable name="jsapos">\'</xsl:variable>
    <xsl:variable name="comma">,</xsl:variable>
    <xsl:variable name="empty_string" select="''"/>
    <xsl:variable name="self" select="generate-id()"/>

    <xsl:choose>
      <xsl:when test="ancestor-or-self::*[@toc][1]/@toc = 'no' or
                      ancestor-or-self::*[@processing-role][1]/@processing-role = 'resource-only'">
        <!-- Continue to children; if they turn @toc back on, connect to the last @toc=yes parent -->
        <xsl:apply-templates>
          <xsl:with-param name="parent" select="$parent"/>
          <xsl:with-param name="contentwin" select="$contentwin"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:when test="@href">

        <xsl:text>var </xsl:text>
        <xsl:value-of select="concat('obj', $self)"/>
        <xsl:text> = { label: "</xsl:text>

        <xsl:choose>
          <xsl:when test="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]">
            <!--<xsl:message> - testing navtitle - <xsl:value-of select="topicmeta/navtitle"/></xsl:message>-->
            <xsl:call-template name="fix-title">
              <xsl:with-param name="text">
                <xsl:value-of select="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]"/>
              </xsl:with-param>
            </xsl:call-template>
          </xsl:when>
          
          <xsl:when test="@navtitle">
            <!--<xsl:message> - testing2 navtitle - <xsl:value-of select="@navtitle"/></xsl:message>-->
            <xsl:call-template name="fix-title">
              <xsl:with-param name="text">
                <xsl:value-of select="@navtitle"/>
              </xsl:with-param>
            </xsl:call-template>
          </xsl:when>
          
          <xsl:otherwise>
            <!--<xsl:message> - testing3 navtitle - <xsl:value-of select="@navtitle"/></xsl:message>-->
            <xsl:call-template name="fix-title">
              <xsl:with-param name="text">
                <xsl:value-of select="@navtitle"/>
              </xsl:with-param>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
        
        
        <xsl:text>", href:"</xsl:text>
        <xsl:call-template name="gethref">
          <xsl:with-param name="ditahref" select="@href"/>
        </xsl:call-template>
        <xsl:text>", target:"</xsl:text><xsl:value-of select="$contentwin"/><xsl:text>" };
    </xsl:text>

        <xsl:text>var </xsl:text>
        <xsl:value-of select="$self"/>
        <xsl:text> = new YAHOO.widget.TextNode(</xsl:text>
        <xsl:value-of select="concat('obj', $self)"/>
        <xsl:text>, </xsl:text>
        <xsl:value-of select="$parent"/>
        <xsl:text>, false);</xsl:text>

        <xsl:apply-templates>
          <xsl:with-param name="parent" select="$self"/>
          <xsl:with-param name="contentwin" select="$contentwin"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:when test="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]">
        <!-- No href, has a navtitle element. Used in DITA-OT 1.5 and later. -->
        <xsl:text>var </xsl:text>
        <xsl:value-of select="$self"/>
        <xsl:text> = new YAHOO.widget.TextNode("</xsl:text>
        <xsl:value-of select="*[contains(@class, ' map/topicmeta ')]/*[contains(@class, ' topic/navtitle ')]"/>
        <xsl:text>", </xsl:text>
        <xsl:value-of select="$parent"/>
        <xsl:text>, false);</xsl:text>

        <xsl:apply-templates>
          <xsl:with-param name="parent" select="$self"/>
          <xsl:with-param name="contentwin" select="$contentwin"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:when test="@navtitle">
        <!-- No href, has navtitle attribute. -->
        <xsl:text>var </xsl:text>
        <xsl:value-of select="$self"/>
        <xsl:text> = new YAHOO.widget.TextNode("</xsl:text>
        <xsl:value-of select="@navtitle"/>
        <xsl:text>", </xsl:text>
        <xsl:value-of select="$parent"/>
        <xsl:text>, false);</xsl:text>

        <xsl:apply-templates>
          <xsl:with-param name="parent" select="$self"/>
          <xsl:with-param name="contentwin" select="$contentwin"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:otherwise>
        <!-- Topicgroup or similar (no href, no title): continue to children -->
        <xsl:apply-templates>
          <xsl:with-param name="parent" select="$parent"/>
          <xsl:with-param name="contentwin" select="$contentwin"/>
        </xsl:apply-templates>
      </xsl:otherwise>
      
    </xsl:choose>
    
  </xsl:template>

  <!-- Remove known problem characters " and < from TOC -->
  <xsl:template name="fix-title">
    <xsl:param name="text"/>
    <xsl:choose>
      <xsl:when test="contains($text,$quote) and contains($text,$lessthan)">
        <xsl:variable name="chopquote">
          <xsl:call-template name="replace-string">
            <xsl:with-param name="text" select="$text"/>
            <xsl:with-param name="from" select="$quote"/>
            <xsl:with-param name="to" select="$quotestring"/>
          </xsl:call-template>
        </xsl:variable>
        <xsl:call-template name="replace-string">
          <xsl:with-param name="text" select="$chopquote"/>
          <xsl:with-param name="from" select="$lessthan"/>
          <xsl:with-param name="to" select="$lessthanstring"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="contains($text,$quote)">
        <xsl:call-template name="replace-string">
          <xsl:with-param name="text" select="$text"/>
          <xsl:with-param name="from" select="$quote"/>
          <xsl:with-param name="to" select="$quotestring"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="contains($text,$lessthan)">
        <xsl:call-template name="replace-string">
          <xsl:with-param name="text" select="$text"/>
          <xsl:with-param name="from" select="$lessthan"/>
          <xsl:with-param name="to" select="$lessthanstring"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$text"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="replace-string">
    <xsl:param name="text"/>
    <xsl:param name="from"/>
    <xsl:param name="to"/>

    <xsl:choose>
      <xsl:when test="contains($text, $from)">

        <xsl:variable name="before" select="substring-before($text, $from)"/>
        <xsl:variable name="after" select="substring-after($text, $from)"/>
        <xsl:variable name="prefix" select="concat($before, $to)"/>

        <xsl:value-of select="$before"/>
        <xsl:value-of select="$to"/>
        <xsl:call-template name="replace-string">
          <xsl:with-param name="text" select="$after"/>
          <xsl:with-param name="from" select="$from"/>
          <xsl:with-param name="to" select="$to"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$text"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>


</xsl:stylesheet>
