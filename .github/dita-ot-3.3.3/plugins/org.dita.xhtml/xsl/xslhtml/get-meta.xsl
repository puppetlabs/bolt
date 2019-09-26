<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2004, 2005 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->

<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<!-- Get each value in each <keywords>. Nested indexterms should have unique entries. Other
     elements (based on keyword) cannot nest. -->
<xsl:key name="meta-keywords" match="*[ancestor::*[contains(@class,' topic/keywords ')]]" use="text()[1]"/>

<xsl:template name="getMeta">

<!-- Processing note:
 getMeta is issued from the topic/topic context, therefore it is looking DOWN
 for most data except for attributes on topic, which will be current context.
-->

  <!-- = = = = = = = = = = = CONTENT = = = = = = = = = = = -->

  <!-- CONTENT: Type -->
  <xsl:apply-templates select="." mode="gen-type-metadata"/>

  <!-- CONTENT: Title - title -->
  <xsl:apply-templates select="*[contains(@class,' topic/title ')] |
                               self::dita/*[1]/*[contains(@class,' topic/title ')]" mode="gen-metadata"/>

  <!-- CONTENT: Description - shortdesc -->
  <xsl:apply-templates select="*[contains(@class,' topic/shortdesc ')] |
                               self::dita/*[1]/*[contains(@class,' topic/shortdesc ')]" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/abstract ')] |
                               self::dita/*[1]/*[contains(@class,' topic/abstract ')]" mode="gen-shortdesc-metadata"/>

  <!-- CONTENT: Source - prolog/source/@href -->
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/source ')]/@href |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/source ')]/@href" mode="gen-metadata"/>

  <!-- CONTENT: Coverage prolog/metadata/category -->
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/category ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/category ')]" mode="gen-metadata"/>

  <!-- CONTENT: Subject - prolog/metadata/keywords -->
  <xsl:apply-templates select="." mode="gen-keywords-metadata"/>

  <!-- CONTENT: Relation - related-links -->
  <xsl:apply-templates select="*[contains(@class,' topic/related-links ')]/descendant::*/@href |
                               self::dita/*/*[contains(@class,' topic/related-links ')]/descendant::*/@href" mode="gen-metadata"/>

  <!-- = = = = = = = = = = = Product - Audience = = = = = = = = = = = -->
  <!-- Audience -->
  <!-- prolog/metadata/audience/@experiencelevel and other attributes -->
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/audience ')]/@experiencelevel |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/audience ')]/@experiencelevel" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/audience ')]/@importance |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/audience ')]/@importance" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/audience ')]/@job |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/audience ')]/@job" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/audience ')]/@name |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/audience ')]/@name" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/audience ')]/@type |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/audience ')]/@type" mode="gen-metadata"/>


  <!-- <prodname> -->
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/prodname ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/prodname ')]" mode="gen-metadata"/>

  <!-- <vrmlist><vrm modification="3" release="2" version="5"/></vrmlist> -->
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/vrmlist ')]/*[contains(@class,' topic/vrm ')]/@version |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/vrmlist ')]/*[contains(@class,' topic/vrm ')]/@version" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/vrmlist ')]/*[contains(@class,' topic/vrm ')]/@release |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/vrmlist ')]/*[contains(@class,' topic/vrm ')]/@release" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/vrmlist ')]/*[contains(@class,' topic/vrm ')]/@modification |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/vrmlist ')]/*[contains(@class,' topic/vrm ')]/@modification" mode="gen-metadata"/>

  <!-- <brand> -->
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/brand ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/brand ')]" mode="gen-metadata"/>
  <!-- <component> -->
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/component ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/component ')]" mode="gen-metadata"/>
  <!-- <featnum> -->
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/featnum ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/featnum ')]" mode="gen-metadata"/>
  <!-- <prognum> -->
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/prognum ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/prognum ')]" mode="gen-metadata"/>
  <!-- <platform> -->
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/platform ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/platform ')]" mode="gen-metadata"/>
  <!-- <series> -->
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/series ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/series ')]" mode="gen-metadata"/>

  <!-- = = = = = = = = = = = INTELLECTUAL PROPERTY = = = = = = = = = = = -->

  <!-- INTELLECTUAL PROPERTY: Contributor - prolog/author -->
  <!-- INTELLECTUAL PROPERTY: Creator -->
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/author ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/author ')]" mode="gen-metadata"/>

  <!-- INTELLECTUAL PROPERTY: Publisher - prolog/publisher -->
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/publisher ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/publisher ')]" mode="gen-metadata"/>

  <!-- INTELLECTUAL PROPERTY: Rights - prolog/copyright -->
  <!-- Put primary first, then secondary, then remainder -->
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/copyright ')][@type='primary'] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/copyright ')][@type='primary']" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/copyright ')][@type='secondary'] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/copyright ')][@type='seconday']" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/copyright ')][not(@type)] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/copyright ')][not(@type)]" mode="gen-metadata"/>

  <!-- Usage Rights - prolog/permissions -->
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/permissions ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/permissions ')]" mode="gen-metadata"/>

  <!-- = = = = = = = = = = = INSTANTIATION = = = = = = = = = = = -->

  <!-- INSTANTIATION: Date - prolog/critdates/created -->
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/created ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/created ')]" mode="gen-metadata"/>

  <!-- prolog/critdates/revised/@modified -->
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/revised ')]/@modified |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/revised ')]/@modified" mode="gen-metadata"/>

  <!-- prolog/critdates/revised/@golive -->
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/revised ')]/@golive |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/revised ')]/@golive" mode="gen-metadata"/>

  <!-- prolog/critdates/revised/@expiry -->
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/revised ')]/@expiry |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/revised ')]/@expiry" mode="gen-metadata"/>

  <!-- prolog/metadata/othermeta -->
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/othermeta ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/othermeta ')]" mode="gen-metadata"/>

  <!-- INSTANTIATION: Format -->
  <xsl:apply-templates select="." mode="gen-format-metadata"/>

  <!-- INSTANTIATION: Identifier --> <!-- id is an attribute on Topic -->
  <xsl:apply-templates select="@id | self::dita/*[1]/@id" mode="gen-metadata"/>

  <!-- INSTANTIATION: Language -->
  <xsl:apply-templates select="@xml:lang | self::dita/*[1]/@xml:lang" mode="gen-metadata"/>

</xsl:template>


<!-- CONTENT: Type -->
<xsl:template match="dita" mode="gen-type-metadata">
  <xsl:apply-templates select="*[1]" mode="gen-type-metadata"/>
</xsl:template>
<xsl:template match="*" mode="gen-type-metadata">
  <meta name="DC.type" content="{name(.)}"/>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- CONTENT: Title - title -->
<xsl:template match="*[contains(@class,' topic/title ')]" mode="gen-metadata">
  <xsl:variable name="titlemeta">
    <xsl:apply-templates select="*|text()" mode="text-only"/>
  </xsl:variable>
  <meta name="DC.title">
    <xsl:attribute name="content"><xsl:value-of select="normalize-space($titlemeta)"/></xsl:attribute>
  </meta>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- CONTENT: Description - shortdesc -->
<xsl:template match="*[contains(@class,' topic/shortdesc ')]" mode="gen-metadata">
  <xsl:variable name="shortmeta">
    <xsl:apply-templates select="*|text()" mode="text-only"/>
  </xsl:variable>
  <meta name="abstract">
    <xsl:attribute name="content"><xsl:value-of select="normalize-space($shortmeta)"/></xsl:attribute>
  </meta>
  <xsl:value-of select="$newline"/>
  <meta name="description">
    <xsl:attribute name="content"><xsl:value-of select="normalize-space($shortmeta)"/></xsl:attribute>
  </meta>
  <xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template match="*[contains(@class,' topic/abstract ')]" mode="gen-shortdesc-metadata">
  <xsl:variable name="shortmeta">
    <xsl:for-each select="*[contains(@class,' topic/shortdesc ')]">
      <xsl:text> </xsl:text>
      <xsl:apply-templates select="*|text()" mode="text-only"/>
    </xsl:for-each>
  </xsl:variable>
  <xsl:if test="normalize-space($shortmeta)!=''">
    <meta name="abstract">
      <xsl:attribute name="content"><xsl:value-of select="normalize-space($shortmeta)"/></xsl:attribute>
    </meta>
    <xsl:value-of select="$newline"/>
    <meta name="description">
      <xsl:attribute name="content"><xsl:value-of select="normalize-space($shortmeta)"/></xsl:attribute>
    </meta>
    <xsl:value-of select="$newline"/>
  </xsl:if>
</xsl:template>

<!-- CONTENT: Source - prolog/source/@href -->
<xsl:template match="*[contains(@class,' topic/source ')]/@href" mode="gen-metadata">
  <meta name="DC.source" content="{normalize-space(.)}"/>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- CONTENT: Coverage prolog/metadata/category -->
<xsl:template match="*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/category ')]" mode="gen-metadata">
  <meta name="DC.coverage" content="{normalize-space(.)}"/>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- CONTENT: Subject - prolog/metadata/keywords -->
<xsl:template match="*" mode="gen-keywords-metadata">
  <xsl:variable name="keywords-content">
    <!-- for each item inside keywords (including nested index terms) -->
    <xsl:for-each select="descendant::*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/keywords ')]/descendant-or-self::*">
      <!-- If this is the first term or keyword with this value -->
      <xsl:if test="generate-id(key('meta-keywords',text()[1])[1])=generate-id(.)">
        <xsl:if test="position()>2"><xsl:text>, </xsl:text></xsl:if>
        <xsl:value-of select="normalize-space(text()[1])"/>
      </xsl:if>
    </xsl:for-each>
  </xsl:variable>

  <xsl:if test="string-length($keywords-content)>0">
    <meta name="DC.subject" content="{$keywords-content}"/>
    <xsl:value-of select="$newline"/>
    <meta name="keywords" content="{$keywords-content}"/>
    <xsl:value-of select="$newline"/>
  </xsl:if>
</xsl:template>

<!-- CONTENT: Relation - related-links -->
<xsl:template match="*[contains(@class,' topic/link ')]/@href" mode="gen-metadata">
 <xsl:variable name="linkmeta" select="normalize-space(.)"/>
 <xsl:choose>
  <xsl:when test="substring($linkmeta,1,1)='#'" />  <!-- ignore internal file links -->
  <xsl:otherwise>
    <xsl:variable name="linkmeta_ext">
     <xsl:choose>
      <xsl:when test="not(../@format) or ../@format = 'dita'">
       <xsl:call-template name="replace-extension">
        <xsl:with-param name="filename" select="$linkmeta"/>
        <xsl:with-param name="extension" select="$OUTEXT"/>
       </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
       <xsl:value-of select="$linkmeta"/>
      </xsl:otherwise>
     </xsl:choose>
    </xsl:variable>
    <meta name="DC.relation" scheme="URI">
      <xsl:attribute name="content"><xsl:value-of select="$linkmeta_ext"/></xsl:attribute>
    </meta>
    <xsl:value-of select="$newline"/>
  </xsl:otherwise>
 </xsl:choose>
</xsl:template>

<!-- Do not let any other @href's inside related-links generate metadata -->
<xsl:template match="*/@href" mode="gen-metadata" priority="0"/>

<!-- INTELLECTUAL PROPERTY: Contributor - prolog/author -->
<!-- INTELLECTUAL PROPERTY: Creator -->
<!-- Default is type='creator' -->
<xsl:template match="*[contains(@class,' topic/author ')]" mode="gen-metadata">
  <xsl:choose>
    <xsl:when test="@type= 'contributor'">
      <meta name="DC.contributor" content="{normalize-space(.)}"/>
    </xsl:when>
    <xsl:otherwise>
      <meta name="DC.creator" content="{normalize-space(.)}"/>
    </xsl:otherwise>
  </xsl:choose>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- INTELLECTUAL PROPERTY: Publisher - prolog/publisher -->
<xsl:template match="*[contains(@class,' topic/publisher ')]" mode="gen-metadata">
  <meta name="DC.publisher" content="{normalize-space(.)}"/>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!--  Rights - prolog/copyright -->
<xsl:template match="*[contains(@class,' topic/copyright ')]" mode="gen-metadata">
  <meta name="copyright">
    <xsl:attribute name="content">
     <xsl:choose>
       <!-- ./copyrholder/text() -->
       <xsl:when test="*[contains(@class,' topic/copyrholder ')]/text()">
         <xsl:value-of select="normalize-space(*[contains(@class,' topic/copyrholder ')])"/>
       </xsl:when>
       <xsl:otherwise>
         <xsl:text>(C) </xsl:text>
         <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'Copyright'"/>
         </xsl:call-template>
       </xsl:otherwise>
     </xsl:choose>
     <!-- copyryear -->
     <xsl:for-each select="*[contains(@class,' topic/copyryear ')]">
      <xsl:text> </xsl:text><xsl:value-of select="@year"/>
     </xsl:for-each>
    </xsl:attribute>
    <xsl:choose>
      <xsl:when test="@type = 'secondary'">
        <xsl:attribute name="type">secondary</xsl:attribute>
      </xsl:when>
      <xsl:otherwise>
        <xsl:attribute name="type">primary</xsl:attribute>
      </xsl:otherwise>
    </xsl:choose>
  </meta>
  <xsl:value-of select="$newline"/>
  <meta name="DC.rights.owner">
    <xsl:attribute name="content">
         <xsl:choose>
       <xsl:when test="*[contains(@class,' topic/copyrholder ')]/text()">
         <xsl:value-of select="normalize-space(*[contains(@class,' topic/copyrholder ')])"/>
       </xsl:when>
       <xsl:otherwise>
         <xsl:text>(C) </xsl:text>
         <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'Copyright'"/>
         </xsl:call-template>
       </xsl:otherwise>
     </xsl:choose>
     <xsl:for-each select="*[contains(@class,' topic/copyryear ')]">
      <xsl:text> </xsl:text><xsl:value-of select="@year"/>
     </xsl:for-each>
    </xsl:attribute>
    <xsl:choose>
      <xsl:when test="@type = 'secondary'">
        <xsl:attribute name="type">secondary</xsl:attribute>
      </xsl:when>
      <xsl:otherwise>
        <xsl:attribute name="type">primary</xsl:attribute>
      </xsl:otherwise>
    </xsl:choose>
  </meta>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- Usage Rights - prolog/permissions -->
<xsl:template match="*[contains(@class,' topic/permissions ')]" mode="gen-metadata">
  <meta name="DC.rights.usage" content="{@view}"/>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- = = = = = = = = = = = Product - Audience = = = = = = = = = = = -->
<!-- Audience -->
<xsl:template match="*[contains(@class,' topic/audience ')]/@experiencelevel" mode="gen-metadata">
  <meta name="DC.audience.experiencelevel" content="{.}"/>
  <xsl:value-of select="$newline"/>
</xsl:template>
<xsl:template match="*[contains(@class,' topic/audience ')]/@importance" mode="gen-metadata">
  <meta name="DC.audience.importance" content="{.}"/>
  <xsl:value-of select="$newline"/>
</xsl:template>
<xsl:template match="*[contains(@class,' topic/audience ')]/@name" mode="gen-metadata">
  <meta name="DC.audience.name" content="{.}"/>
  <xsl:value-of select="$newline"/>
</xsl:template>
<xsl:template match="*[contains(@class,' topic/audience ')]/@job" mode="gen-metadata">
 <xsl:choose>
  <xsl:when test=".='other'">
   <meta name="DC.audience.job" content="{normalize-space(../@otherjob)}"/>
  </xsl:when>
  <xsl:otherwise>
   <meta name="DC.audience.job" content="{.}"/>
  </xsl:otherwise>
 </xsl:choose>
 <xsl:value-of select="$newline"/>
</xsl:template>
<xsl:template match="*[contains(@class,' topic/audience ')]/@type" mode="gen-metadata">
 <xsl:choose>
  <xsl:when test=".='other'">
   <meta name="DC.audience.type" content="{normalize-space(../@othertype)}"/>
  </xsl:when>
  <xsl:otherwise>
   <meta name="DC.audience.type" content="{.}"/>
  </xsl:otherwise>
 </xsl:choose>
  <xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template match="*[contains(@class,' topic/prodname ')]" mode="gen-metadata">
  <xsl:variable name="prodnamemeta">
    <xsl:apply-templates select="*|text()" mode="text-only"/>
  </xsl:variable>
  <meta name="prodname">
    <xsl:attribute name="content"><xsl:value-of select="normalize-space($prodnamemeta)"/></xsl:attribute>
  </meta>
  <xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template match="*[contains(@class,' topic/vrm ')]/@version" mode="gen-metadata">
  <meta name="version" content="{.}"/>
  <xsl:value-of select="$newline"/>
</xsl:template>
<xsl:template match="*[contains(@class,' topic/vrm ')]/@release" mode="gen-metadata">
  <meta name="release" content="{.}"/>
  <xsl:value-of select="$newline"/>
</xsl:template>
<xsl:template match="*[contains(@class,' topic/vrm ')]/@modification" mode="gen-metadata">
  <meta name="modification" content="{.}"/>
  <xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template match="*[contains(@class,' topic/brand ')]" mode="gen-metadata">
  <xsl:variable name="brandmeta">
    <xsl:apply-templates select="*|text()" mode="text-only"/>
  </xsl:variable>
  <meta name="brand">
    <xsl:attribute name="content"><xsl:value-of select="normalize-space($brandmeta)"/></xsl:attribute>
  </meta>
  <xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template match="*[contains(@class,' topic/component ')]" mode="gen-metadata">
  <xsl:variable name="componentmeta">
    <xsl:apply-templates select="*|text()" mode="text-only"/>
  </xsl:variable>
  <meta name="component">
    <xsl:attribute name="content"><xsl:value-of select="normalize-space($componentmeta)"/></xsl:attribute>
  </meta>
  <xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template match="*[contains(@class,' topic/featnum ')]" mode="gen-metadata">
  <xsl:variable name="featnummeta">
    <xsl:apply-templates select="*|text()" mode="text-only"/>
  </xsl:variable>
  <meta name="featnum">
    <xsl:attribute name="content"><xsl:value-of select="normalize-space($featnummeta)"/></xsl:attribute>
  </meta>
  <xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template match="*[contains(@class,' topic/prognum ')]" mode="gen-metadata">
  <xsl:variable name="prognummeta">
    <xsl:apply-templates select="*|text()" mode="text-only"/>
  </xsl:variable>
  <meta name="prognum">
    <xsl:attribute name="content"><xsl:value-of select="normalize-space($prognummeta)"/></xsl:attribute>
  </meta>
  <xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template match="*[contains(@class,' topic/platform ')]" mode="gen-metadata">
  <xsl:variable name="platformmeta">
    <xsl:apply-templates select="*|text()" mode="text-only"/>
  </xsl:variable>
  <meta name="platform">
    <xsl:attribute name="content"><xsl:value-of select="normalize-space($platformmeta)"/></xsl:attribute>
  </meta>
  <xsl:value-of select="$newline"/>
</xsl:template>

<xsl:template match="*[contains(@class,' topic/series ')]" mode="gen-metadata">
  <xsl:variable name="seriesmeta">
    <xsl:apply-templates select="*|text()" mode="text-only"/>
  </xsl:variable>
  <meta name="series">
    <xsl:attribute name="content"><xsl:value-of select="normalize-space($seriesmeta)"/></xsl:attribute>
  </meta>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- INSTANTIATION: Date - prolog/critdates/created -->
<xsl:template match="*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/created ')]" mode="gen-metadata">
  <meta name="DC.date.created" content="{@date}"/>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- prolog/critdates/revised/@modified -->
<xsl:template match="*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/revised ')]/@modified" mode="gen-metadata">
  <meta name="DC.date.modified" content="{.}"/>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- prolog/critdates/revised/@golive -->
<xsl:template match="*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/revised ')]/@golive" mode="gen-metadata">
  <meta name="DC.date.issued" content="{.}"/>
  <xsl:value-of select="$newline"/>
  <meta name="DC.date.available" content="{.}"/>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- prolog/critdates/revised/@expiry -->
<xsl:template match="*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/revised ')]/@expiry" mode="gen-metadata">
  <meta name="DC.date.expiry" content="{.}"/>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- prolog/metadata/othermeta -->
<xsl:template match="*[contains(@class,' topic/othermeta ')]" mode="gen-metadata">
  <meta name="{@name}" content="{@content}"/>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- INSTANTIATION: Format -->
<!-- this value is based on output format used for DC indexing, not source.
     Put in this odd template for easy overriding, if creating another output format. -->
<xsl:template match="*" mode="gen-format-metadata">
  <meta name="DC.format" content="XHTML"/>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- INSTANTIATION: Identifier --> <!-- id is an attribute on Topic -->
<xsl:template match="@id" mode="gen-metadata">
  <meta name="DC.identifier" content="{.}"/>
  <xsl:value-of select="$newline"/>
</xsl:template>

<!-- INSTANTIATION: Language -->
<!-- ideally, take the first token of the language attribute value -->
<xsl:template match="@xml:lang" mode="gen-metadata">
  <meta name="DC.language" content="{.}"/>
  <xsl:value-of select="$newline"/>
</xsl:template>

</xsl:stylesheet>
