<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  exclude-result-prefixes="xs"
  version="2.0">

  <xsl:output doctype-public="-//OASIS//DTD DITA Reference//EN"
    doctype-system="reference.dtd"/>

  <xsl:strip-space elements="*"/>

  <xsl:param name="output-dir.url"/>

  <xsl:template match="/">
    <xsl:call-template name="all"/>
    <xsl:call-template name="separate"/>
  </xsl:template>

  <xsl:template name="all">
    <xsl:comment> Generated from plugin source, do not edit! </xsl:comment>
    <reference id="all-extension-points">
      <title id="title" outputclass="generated">All DITA-OT extension points</title>
      <titlealts>
        <navtitle>All extension points</navtitle>
      </titlealts>
      <shortdesc id="shortdesc">The pre-defined extension points can be used to add new functionality to DITA-OT. If
        your toolkit installation includes custom plug-ins that define additional extension points, you can add to this
        list by rebuilding the DITA-OT documentation.</shortdesc>
        <refbody>
          <section>
            <dl>
              <xsl:apply-templates select="//extension-point" mode="reuse">
                <xsl:sort select="@name"/>
              </xsl:apply-templates>
            </dl>
          </section>
        </refbody>
    </reference>
  </xsl:template>

  <xsl:template name="separate">
    <!--xsl:for-each select="//transtype/param"-->
    <xsl:for-each select="//plugin">
      <xsl:variable name="id" select="@id"/>
      <xsl:message>Writing <xsl:value-of select="$output-dir.url"/>extension-points-in-<xsl:value-of select="$id"/>.dita</xsl:message>
      <xsl:result-document href="{$output-dir.url}/extension-points-in-{$id}.dita"
        doctype-public="-//OASIS//DTD DITA Reference//EN"
        doctype-system="reference.dtd">
        <xsl:comment> Generated from plugin source, do not edit! </xsl:comment>
        <reference id="{$id}-ext">
          <title outputclass="generated">
            <xsl:text>Extension points in </xsl:text>
            <codeph><xsl:value-of select="@id"/></codeph>
          </title>
          <titlealts>
            <navtitle id="navtitle">
              <xsl:value-of select="(transtype/@desc)[1]"/>
            </navtitle>
          </titlealts>
          <shortdesc id="shortdesc">The <codeph><xsl:value-of select="@id"/></codeph> plug-in provides extension points
            to modify <xsl:value-of select="(transtype/@desc)[1]"/> processing.</shortdesc>
          <refbody>
            <section>
              <dl>
                <xsl:apply-templates select="extension-point">
                  <xsl:sort select="@id"/>
                </xsl:apply-templates>
              </dl>
            </section>
          </refbody>
        </reference>
      </xsl:result-document>
    </xsl:for-each>
  </xsl:template>

  <!--xsl:template match="transtype" mode="inherit" as="element(param)*">
    <xsl:sequence select="param"/>
    <xsl:variable name="extends" as="xs:string?">
      <xsl:choose>
        <xsl:when test="@name = 'base'"/>
        <xsl:when test="@extends">
          <xsl:value-of select="@extends"/>
        </xsl:when>
        <xsl:otherwise>base</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="exists($extends)">
      <xsl:apply-templates select="//transtype[tokenize(@name, '\s+') = $extends]" mode="inherit"/>
    </xsl:if>
  </xsl:template-->

  <xsl:template match="extension-point">
    <dlentry id="{@id}">
      <xsl:if test="@deprecated = 'true'">
        <xsl:attribute name="importance">deprecated</xsl:attribute>
      </xsl:if>
      <xsl:if test="@required = 'true'">
        <xsl:attribute name="importance">required</xsl:attribute>
      </xsl:if>
      <dt>
        <parmname>
          <xsl:value-of select="@id"/>
        </parmname>
        <ph>
          <indexterm>
            <parmname><xsl:value-of select="@id"/></parmname>
          </indexterm>
          <indexterm>extension points<indexterm>
            <parmname><xsl:value-of select="@id"/></parmname>
          </indexterm></indexterm>
        </ph>
        <xsl:if test="parent::*[@deprecated = 'true']">
          <ph>
            <indexterm>deprecated features<indexterm>extension points<indexterm>
              <parmname><xsl:value-of select="@id"/></parmname>
            </indexterm></indexterm>
            </indexterm>
          </ph>
        </xsl:if>
      </dt>
      <dd id="{@id}.desc">
        <xsl:value-of select="@name"/>
      </dd>
    </dlentry>
  </xsl:template>

  <xsl:template match="extension-point" mode="reuse">
    <xsl:variable name="containing-plugin" select="ancestor::plugin/@id"/>
    <dlentry id="{@id}">
      <xsl:if test="@deprecated = 'true'">
        <xsl:attribute name="importance">deprecated</xsl:attribute>
      </xsl:if>
      <xsl:if test="@required = 'true'">
        <xsl:attribute name="importance">required</xsl:attribute>
      </xsl:if>
      <dt>
        <parmname>
          <xsl:value-of select="@id"/>
        </parmname>
        <ph>
          <indexterm>
            <parmname><xsl:value-of select="@id"/></parmname>
          </indexterm>
          <indexterm>extension points<indexterm>
            <parmname><xsl:value-of select="@id"/></parmname>
          </indexterm></indexterm>
        </ph>
        <xsl:if test="parent::*[@deprecated = 'true']">
          <ph>
            <indexterm>deprecated features<indexterm>extension points<indexterm>
                <parmname><xsl:value-of select="@id"/></parmname>
            </indexterm></indexterm>
            </indexterm>
          </ph>
        </xsl:if>
      </dt>
      <!-- Changing the keyref to "extension-points-in-{$containing-plugin}/{@id}" would link to the exact parameter. -->
      <dd>Defined in plug-in
        <xref keyref="extension-points-in-{$containing-plugin}">
          <codeph><xsl:value-of select="$containing-plugin"/></codeph>
        </xref>.
      </dd>
      <dd conkeyref="extension-points-in-{$containing-plugin}/{@id}.desc" id="{@id}.desc"/>
    </dlentry>
  </xsl:template>

</xsl:stylesheet>
