<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2015 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dita-ot="http://dita-ot.sourceforge.net/ns/201007/dita-ot"
                xmlns:ditamsg="http://dita-ot.sourceforge.net/ns/200704/ditamsg"
                version="2.0"
                exclude-result-prefixes="xs dita-ot ditamsg">
  
  <xsl:import href="plugin:org.dita.html5:xsl/map2html5Impl.xsl"/>
  
  <xsl:param name="nav-toc" as="xs:string?"/>
  <xsl:param name="FILEDIR" as="xs:string?"/>
  <xsl:param name="FILENAME" as="xs:string?"/>
  <xsl:param name="input.map.url" as="xs:string?"/>
  
  <xsl:variable name="input.map" as="document-node()?">
    <xsl:apply-templates select="document($input.map.url)" mode="normalize-map"/>
  </xsl:variable>

  <xsl:attribute-set name="toc">
    <xsl:attribute name="role">toc</xsl:attribute>
  </xsl:attribute-set>

  <xsl:template match="*" mode="gen-user-sidetoc">
    <xsl:if test="$nav-toc = ('partial', 'full')">
      <nav xsl:use-attribute-sets="toc">
        <ul>
          <xsl:choose>
            <xsl:when test="$nav-toc = 'partial'">
              <xsl:apply-templates select="$current-topicref" mode="toc-pull">
                <xsl:with-param name="pathFromMaplist" select="$PATH2PROJ" as="xs:string"/>
                <xsl:with-param name="children" as="element()*">
                    <xsl:apply-templates select="$current-topicref/*[contains(@class, ' map/topicref ')]" mode="toc">
                    <xsl:with-param name="pathFromMaplist" select="$PATH2PROJ" as="xs:string"/>
                  </xsl:apply-templates>
                </xsl:with-param>
              </xsl:apply-templates>
            </xsl:when>
            <xsl:when test="$nav-toc = 'full'">
              <xsl:apply-templates select="$input.map" mode="toc">
                <xsl:with-param name="pathFromMaplist" select="$PATH2PROJ" as="xs:string"/>
              </xsl:apply-templates>
            </xsl:when>
          </xsl:choose>
        </ul>
      </nav>
    </xsl:if>
  </xsl:template>
  
  <xsl:variable name="current-file" select="dita-ot:normalize-href(if ($FILEDIR = '.') then $FILENAME else concat($FILEDIR, '/', $FILENAME))" as="xs:string?"/>
  <xsl:variable name="current-topicrefs" select="$input.map//*[contains(@class, ' map/topicref ')][dita-ot:get-path($PATH2PROJ, .) = $current-file]" as="element()*"/>
  <xsl:variable name="current-topicref" select="$current-topicrefs[1]" as="element()?"/>
  
  <xsl:template match="*[contains(@class, ' map/map ')]" mode="toc-pull">
    <xsl:param name="pathFromMaplist" select="$PATH2PROJ" as="xs:string"/>
    <xsl:param name="children" select="()" as="element()*"/>
    <xsl:param name="parent" select="parent::*" as="element()?"/>
    <xsl:copy-of select="$children"/>
  </xsl:template>
  
  <xsl:template match="*" mode="toc-pull" priority="-10">
    <xsl:param name="pathFromMaplist" as="xs:string"/>
    <xsl:param name="children" select="()" as="element()*"/>
    <xsl:param name="parent" select="parent::*" as="element()?"/>
    <xsl:apply-templates select="$parent" mode="toc-pull">
      <xsl:with-param name="pathFromMaplist" select="$pathFromMaplist"/>
      <xsl:with-param name="children" select="$children"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' map/topicref ')]
                        [not(@toc = 'no')]
                        [not(@processing-role = 'resource-only')]"
                mode="toc-pull" priority="10">
    <xsl:param name="pathFromMaplist" as="xs:string"/>
    <xsl:param name="children" select="()" as="element()*"/>
    <xsl:param name="parent" select="parent::*" as="element()?"/>
    <xsl:variable name="title">
      <xsl:apply-templates select="." mode="get-navtitle"/>
    </xsl:variable>
    <xsl:apply-templates select="$parent" mode="toc-pull">
      <xsl:with-param name="pathFromMaplist" select="$pathFromMaplist"/>
      <xsl:with-param name="children" as="element()*">
        <xsl:apply-templates select="preceding-sibling::*[contains(@class, ' map/topicref ')]" mode="toc">
          <xsl:with-param name="pathFromMaplist" select="$pathFromMaplist"/>
        </xsl:apply-templates>
        <xsl:choose>
          <xsl:when test="normalize-space($title)">
            <li>
              <xsl:if test=". is $current-topicref">
                <xsl:attribute name="class">active</xsl:attribute>
              </xsl:if>
              <xsl:choose>
                <xsl:when test="normalize-space(@href)">
                  <a>
                    <xsl:attribute name="href">
                      <xsl:if test="not(@scope = 'external')">
                        <xsl:value-of select="$pathFromMaplist"/>
                      </xsl:if>
                      <xsl:choose>
                        <xsl:when test="@copy-to and not(contains(@chunk, 'to-content')) and 
                                        (not(@format) or @format = 'dita' or @format = 'ditamap') ">
                          <xsl:call-template name="replace-extension">
                            <xsl:with-param name="filename" select="@copy-to"/>
                            <xsl:with-param name="extension" select="$OUTEXT"/>
                          </xsl:call-template>
                          <xsl:if test="not(contains(@copy-to, '#')) and contains(@href, '#')">
                            <xsl:value-of select="concat('#', substring-after(@href, '#'))"/>
                          </xsl:if>
                        </xsl:when>
                        <xsl:when test="not(@scope = 'external') and (not(@format) or @format = 'dita' or @format = 'ditamap')">
                          <xsl:call-template name="replace-extension">
                            <xsl:with-param name="filename" select="@href"/>
                            <xsl:with-param name="extension" select="$OUTEXT"/>
                          </xsl:call-template>
                        </xsl:when>
                        <xsl:otherwise>
                          <xsl:value-of select="@href"/>
                        </xsl:otherwise>
                      </xsl:choose>
                    </xsl:attribute>
                    <xsl:value-of select="$title"/>
                  </a>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="$title"/>
                </xsl:otherwise>
              </xsl:choose>
              <xsl:if test="exists($children)">
                <ul xsl:use-attribute-sets="nav.ul">
                  <xsl:copy-of select="$children"/>
                </ul>
              </xsl:if>
            </li>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="*[contains(@class, ' map/topicref ')]" mode="toc">
              <xsl:with-param name="pathFromMaplist" select="$pathFromMaplist"/>
            </xsl:apply-templates>
          </xsl:otherwise>
        </xsl:choose>
        <xsl:apply-templates select="following-sibling::*[contains(@class, ' map/topicref ')]" mode="toc">
          <xsl:with-param name="pathFromMaplist" select="$pathFromMaplist"/>
        </xsl:apply-templates>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:attribute-set name="nav.ul">
  </xsl:attribute-set>
  
  <xsl:template match="*" mode="toc" priority="-10">
    <xsl:param name="pathFromMaplist" as="xs:string"/>
    <xsl:apply-templates select="*[contains(@class, ' map/topicref ')]" mode="toc">
      <xsl:with-param name="pathFromMaplist" select="$pathFromMaplist"/>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' map/topicref ')]
                        [not(@toc = 'no')]
                        [not(@processing-role = 'resource-only')]"
                mode="toc" priority="10">
    <xsl:param name="pathFromMaplist" as="xs:string"/>
    <xsl:param name="children" select="if ($nav-toc = 'full') then *[contains(@class, ' map/topicref ')] else ()" as="element()*"/>
    <xsl:variable name="title">
      <xsl:apply-templates select="." mode="get-navtitle"/>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="normalize-space($title)">
        <li>
          <xsl:if test=". is $current-topicref">
            <xsl:attribute name="class">active</xsl:attribute>
          </xsl:if>
          <xsl:choose>
            <xsl:when test="normalize-space(@href)">
              <a>
                <xsl:attribute name="href">
                  <xsl:if test="not(@scope = 'external')">
                    <xsl:value-of select="$pathFromMaplist"/>
                  </xsl:if>
                  <xsl:choose>
                    <xsl:when test="@copy-to and not(contains(@chunk, 'to-content')) and 
                                    (not(@format) or @format = 'dita' or @format = 'ditamap') ">
                      <xsl:call-template name="replace-extension">
                        <xsl:with-param name="filename" select="@copy-to"/>
                        <xsl:with-param name="extension" select="$OUTEXT"/>
                      </xsl:call-template>
                      <xsl:if test="not(contains(@copy-to, '#')) and contains(@href, '#')">
                        <xsl:value-of select="concat('#', substring-after(@href, '#'))"/>
                      </xsl:if>
                    </xsl:when>
                    <xsl:when test="not(@scope = 'external') and (not(@format) or @format = 'dita' or @format = 'ditamap')">
                      <xsl:call-template name="replace-extension">
                        <xsl:with-param name="filename" select="@href"/>
                        <xsl:with-param name="extension" select="$OUTEXT"/>
                      </xsl:call-template>
                    </xsl:when>
                    <xsl:otherwise>
                      <xsl:value-of select="@href"/>
                    </xsl:otherwise>
                  </xsl:choose>
                </xsl:attribute>
                <xsl:value-of select="$title"/>
              </a>
            </xsl:when>
            <xsl:otherwise>
              <span>
                <xsl:value-of select="$title"/>
              </span>
            </xsl:otherwise>
          </xsl:choose>
          <xsl:if test="exists($children)">
            <ul>
              <xsl:apply-templates select="$children" mode="#current">
                <xsl:with-param name="pathFromMaplist" select="$pathFromMaplist"/>
              </xsl:apply-templates>
            </ul>
          </xsl:if>
        </li>
      </xsl:when>
    </xsl:choose>
  </xsl:template>
  
  <xsl:function name="dita-ot:get-path" as="xs:string?">
    <xsl:param name="pathFromMaplist" as="xs:string"/>
    <xsl:param name="node" as="element()"/>
    <xsl:for-each select="$node">
      <xsl:value-of>
        <xsl:if test="not(@scope = 'external')">
          <xsl:call-template name="strip-leading-parent">
            <xsl:with-param name="path" select="$pathFromMaplist"/>
          </xsl:call-template>
        </xsl:if>
        <xsl:choose>
          <xsl:when test="@copy-to and not(contains(@chunk, 'to-content')) and
                          (not(@format) or @format = 'dita' or @format = 'ditamap') ">
            <xsl:value-of select="@copy-to"/>
          </xsl:when>
          <xsl:when test="contains(@chunk, 'to-content')">
            <xsl:value-of select="substring-before(@href,'#')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="@href"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:value-of>
    </xsl:for-each>
  </xsl:function>
  
  <xsl:template name="strip-leading-parent">
    <xsl:param name="path" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="starts-with($path, '../')">
        <xsl:call-template name="strip-leading-parent">
          <xsl:with-param name="path" select="substring($path, 4)"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$path"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
