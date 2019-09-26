<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:ast="com.elovirta.dita.markdown"
                exclude-result-prefixes="xs ast">

<xsl:key name="meta-keywords" match="*[ancestor::*[contains(@class,' topic/keywords ')]]" use="text()[1]"/>

<xsl:template name="getMeta">
  <xsl:variable name="fields" as="element()*">
    <xsl:for-each select="*[contains(@class, ' topic/prolog ')] | /dita/*[1]/*[contains(@class, ' topic/prolog ')]">
      <xsl:call-template name="get-value">
        <xsl:with-param name="values" select="*[contains(@class, ' topic/author ')]"/>
      </xsl:call-template>
      <xsl:call-template name="get-value">
        <xsl:with-param name="values" select="*[contains(@class, ' topic/source ')]"/>
      </xsl:call-template>
      <xsl:call-template name="get-value">
        <xsl:with-param name="values" select="*[contains(@class, ' topic/publisher ')]"/>
      </xsl:call-template>
      <xsl:call-template name="get-value">
        <xsl:with-param name="values" select="*[contains(@class, ' topic/permissions ')]/@view"/>
        <xsl:with-param name="key" select="'permissions'"/>
      </xsl:call-template>
      <xsl:for-each select="*[contains(@class, ' topic/metadata ')]">
        <xsl:call-template name="get-value">
          <xsl:with-param name="values" select="*[contains(@class, ' topic/audience ')]"/>
        </xsl:call-template>
        <xsl:call-template name="get-value">
          <xsl:with-param name="values" select="*[contains(@class, ' topic/category ')]"/>
        </xsl:call-template>
        <xsl:call-template name="get-value">
          <xsl:with-param name="values" select="*[contains(@class, ' topic/keywords ')]/*[contains(@class, ' topic/keyword ')]"/>
        </xsl:call-template>
      </xsl:for-each>
      <xsl:call-template name="get-value">
        <xsl:with-param name="values" select="*[contains(@class, ' topic/resourceid ')]/@appid"/>
        <xsl:with-param name="key" select="'resourceid'"/>
      </xsl:call-template>
    </xsl:for-each>
  </xsl:variable>
  <xsl:if test="exists($fields)">
    <head>
      <map>
        <xsl:copy-of select="$fields"/>
      </map>
    </head>
  </xsl:if>
  <!--
  <xsl:apply-templates select="." mode="gen-type-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/title ')] |
                               self::dita/*[1]/*[contains(@class,' topic/title ')]" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/shortdesc ')] |
                               self::dita/*[1]/*[contains(@class,' topic/shortdesc ')]" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/abstract ')] |
                               self::dita/*[1]/*[contains(@class,' topic/abstract ')]" mode="gen-shortdesc-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/source ')]/@href |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/source ')]/@href" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/category ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/category ')]" mode="gen-metadata"/>
  <xsl:apply-templates select="." mode="gen-keywords-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/related-links ')]/descendant::*/@href |
                               self::dita/*/*[contains(@class,' topic/related-links ')]/descendant::*/@href" mode="gen-metadata"/>
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
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/prodname ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/prodname ')]" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/vrmlist ')]/*[contains(@class,' topic/vrm ')]/@version |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/vrmlist ')]/*[contains(@class,' topic/vrm ')]/@version" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/vrmlist ')]/*[contains(@class,' topic/vrm ')]/@release |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/vrmlist ')]/*[contains(@class,' topic/vrm ')]/@release" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/vrmlist ')]/*[contains(@class,' topic/vrm ')]/@modification |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/vrmlist ')]/*[contains(@class,' topic/vrm ')]/@modification" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/brand ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/brand ')]" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/component ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/component ')]" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/featnum ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/featnum ')]" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/prognum ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/prognum ')]" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/platform ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/platform ')]" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/series ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/prodinfo ')]/*[contains(@class,' topic/series ')]" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/author ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/author ')]" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/publisher ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/publisher ')]" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/copyright ')][@type='primary'] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/copyright ')][@type='primary']" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/copyright ')][@type='secondary'] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/copyright ')][@type='seconday']" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/copyright ')][not(@type)] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/copyright ')][not(@type)]" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/permissions ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/permissions ')]" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/created ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/created ')]" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/revised ')]/@modified |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/revised ')]/@modified" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/revised ')]/@golive |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/revised ')]/@golive" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/revised ')]/@expiry |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/revised ')]/@expiry" mode="gen-metadata"/>
  <xsl:apply-templates select="*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/othermeta ')] |
                               self::dita/*[1]/*[contains(@class,' topic/prolog ')]/*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/othermeta ')]" mode="gen-metadata"/>
  <xsl:apply-templates select="." mode="gen-format-metadata"/>
  <xsl:apply-templates select="@id | self::dita/*[1]/@id" mode="gen-metadata"/>
  <xsl:apply-templates select="@xml:lang | self::dita/*[1]/@xml:lang" mode="gen-metadata"/>
  -->
</xsl:template>

  <xsl:template name="get-value">
    <xsl:param name="values" as="node()*"/>
    <xsl:param name="key" select="$values[1]/name()" as="xs:string?"/>
    <xsl:choose>
      <xsl:when test="count($values) eq 1">
        <entry key="{$key}">
          <xsl:value-of select="$values"/>
        </entry>
      </xsl:when>
      <xsl:when test="count($values) gt 1">
        <entry key="{$key}">
          <array>
            <xsl:for-each select="$values">
              <entry>
                <xsl:value-of select="."/>
              </entry>
            </xsl:for-each>
          </array>
        </entry>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

<!-- CONTENT: Type -->
<xsl:template match="dita" mode="gen-type-metadata">
  <xsl:apply-templates select="*[1]" mode="gen-type-metadata"/>
</xsl:template>
<xsl:template match="*" mode="gen-type-metadata">
  <meta name="DC.Type" content="{name(.)}"/>
  
</xsl:template>

<!-- CONTENT: Title - title -->
<xsl:template match="*[contains(@class,' topic/title ')]" mode="gen-metadata">
  <xsl:variable name="titlemeta">
    <xsl:apply-templates select="*|text()" mode="text-only"/>
  </xsl:variable>
  <meta name="DC.Title">
    <xsl:attribute name="content"><xsl:value-of select="normalize-space($titlemeta)"/></xsl:attribute>
  </meta>
  
</xsl:template>

<!-- CONTENT: Description - shortdesc -->
<xsl:template match="*[contains(@class,' topic/shortdesc ')]" mode="gen-metadata">
  <xsl:variable name="shortmeta">
    <xsl:apply-templates select="*|text()" mode="text-only"/>
  </xsl:variable>
  <meta name="abstract">
    <xsl:attribute name="content"><xsl:value-of select="normalize-space($shortmeta)"/></xsl:attribute>
  </meta>
  
  <meta name="description">
    <xsl:attribute name="content"><xsl:value-of select="normalize-space($shortmeta)"/></xsl:attribute>
  </meta>
  
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
    
    <meta name="description">
      <xsl:attribute name="content"><xsl:value-of select="normalize-space($shortmeta)"/></xsl:attribute>
    </meta>
    
  </xsl:if>
</xsl:template>

<!-- CONTENT: Source - prolog/source/@href -->
<xsl:template match="*[contains(@class,' topic/source ')]/@href" mode="gen-metadata">
  <meta name="DC.Source" content="{normalize-space(.)}"/>
  
</xsl:template>

<!-- CONTENT: Coverage prolog/metadata/category -->
<xsl:template match="*[contains(@class,' topic/metadata ')]/*[contains(@class,' topic/category ')]" mode="gen-metadata">
  <meta name="DC.Coverage" content="{normalize-space(.)}"/>
  
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
    
    <meta name="keywords" content="{$keywords-content}"/>
    
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
    <meta name="DC.Relation" scheme="URI">
      <xsl:attribute name="content"><xsl:value-of select="$linkmeta_ext"/></xsl:attribute>
    </meta>
    
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
      <meta name="DC.Contributor" content="{normalize-space(.)}"/>
    </xsl:when>
    <xsl:otherwise>
      <meta name="DC.Creator" content="{normalize-space(.)}"/>
    </xsl:otherwise>
  </xsl:choose>
  
</xsl:template>

<!-- INTELLECTUAL PROPERTY: Publisher - prolog/publisher -->
<xsl:template match="*[contains(@class,' topic/publisher ')]" mode="gen-metadata">
  <meta name="DC.Publisher" content="{normalize-space(.)}"/>
  
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
  
  <meta name="DC.Rights.Owner">
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
  
</xsl:template>

<!-- Usage Rights - prolog/permissions -->
<xsl:template match="*[contains(@class,' topic/permissions ')]" mode="gen-metadata">
  <meta name="DC.Rights.Usage" content="{@view}"/>
  
</xsl:template>

<!-- = = = = = = = = = = = Product - Audience = = = = = = = = = = = -->
<!-- Audience -->
<xsl:template match="*[contains(@class,' topic/audience ')]/@experiencelevel" mode="gen-metadata">
  <meta name="DC.Audience.Experiencelevel" content="{.}"/>
  
</xsl:template>
<xsl:template match="*[contains(@class,' topic/audience ')]/@importance" mode="gen-metadata">
  <meta name="DC.Audience.Importance" content="{.}"/>
  
</xsl:template>
<xsl:template match="*[contains(@class,' topic/audience ')]/@name" mode="gen-metadata">
  <meta name="DC.Audience.Name" content="{.}"/>
  
</xsl:template>
<xsl:template match="*[contains(@class,' topic/audience ')]/@job" mode="gen-metadata">
 <xsl:choose>
  <xsl:when test=".='other'">
   <meta name="DC.Audience.Job" content="{normalize-space(../@otherjob)}"/>
  </xsl:when>
  <xsl:otherwise>
   <meta name="DC.Audience.Job" content="{.}"/>
  </xsl:otherwise>
 </xsl:choose>
 
</xsl:template>
<xsl:template match="*[contains(@class,' topic/audience ')]/@type" mode="gen-metadata">
 <xsl:choose>
  <xsl:when test=".='other'">
   <meta name="DC.Audience.Type" content="{normalize-space(../@othertype)}"/>
  </xsl:when>
  <xsl:otherwise>
   <meta name="DC.Audience.Type" content="{.}"/>
  </xsl:otherwise>
 </xsl:choose>
  
</xsl:template>

<xsl:template match="*[contains(@class,' topic/prodname ')]" mode="gen-metadata">
  <xsl:variable name="prodnamemeta">
    <xsl:apply-templates select="*|text()" mode="text-only"/>
  </xsl:variable>
  <meta name="prodname">
    <xsl:attribute name="content"><xsl:value-of select="normalize-space($prodnamemeta)"/></xsl:attribute>
  </meta>
  
</xsl:template>

<xsl:template match="*[contains(@class,' topic/vrm ')]/@version" mode="gen-metadata">
  <meta name="version" content="{.}"/>
  
</xsl:template>
<xsl:template match="*[contains(@class,' topic/vrm ')]/@release" mode="gen-metadata">
  <meta name="release" content="{.}"/>
  
</xsl:template>
<xsl:template match="*[contains(@class,' topic/vrm ')]/@modification" mode="gen-metadata">
  <meta name="modification" content="{.}"/>
  
</xsl:template>

<xsl:template match="*[contains(@class,' topic/brand ')]" mode="gen-metadata">
  <xsl:variable name="brandmeta">
    <xsl:apply-templates select="*|text()" mode="text-only"/>
  </xsl:variable>
  <meta name="brand">
    <xsl:attribute name="content"><xsl:value-of select="normalize-space($brandmeta)"/></xsl:attribute>
  </meta>
  
</xsl:template>

<xsl:template match="*[contains(@class,' topic/component ')]" mode="gen-metadata">
  <xsl:variable name="componentmeta">
    <xsl:apply-templates select="*|text()" mode="text-only"/>
  </xsl:variable>
  <meta name="component">
    <xsl:attribute name="content"><xsl:value-of select="normalize-space($componentmeta)"/></xsl:attribute>
  </meta>
  
</xsl:template>

<xsl:template match="*[contains(@class,' topic/featnum ')]" mode="gen-metadata">
  <xsl:variable name="featnummeta">
    <xsl:apply-templates select="*|text()" mode="text-only"/>
  </xsl:variable>
  <meta name="featnum">
    <xsl:attribute name="content"><xsl:value-of select="normalize-space($featnummeta)"/></xsl:attribute>
  </meta>
  
</xsl:template>

<xsl:template match="*[contains(@class,' topic/prognum ')]" mode="gen-metadata">
  <xsl:variable name="prognummeta">
    <xsl:apply-templates select="*|text()" mode="text-only"/>
  </xsl:variable>
  <meta name="prognum">
    <xsl:attribute name="content"><xsl:value-of select="normalize-space($prognummeta)"/></xsl:attribute>
  </meta>
  
</xsl:template>

<xsl:template match="*[contains(@class,' topic/platform ')]" mode="gen-metadata">
  <xsl:variable name="platformmeta">
    <xsl:apply-templates select="*|text()" mode="text-only"/>
  </xsl:variable>
  <meta name="platform">
    <xsl:attribute name="content"><xsl:value-of select="normalize-space($platformmeta)"/></xsl:attribute>
  </meta>
  
</xsl:template>

<xsl:template match="*[contains(@class,' topic/series ')]" mode="gen-metadata">
  <xsl:variable name="seriesmeta">
    <xsl:apply-templates select="*|text()" mode="text-only"/>
  </xsl:variable>
  <meta name="series">
    <xsl:attribute name="content"><xsl:value-of select="normalize-space($seriesmeta)"/></xsl:attribute>
  </meta>
  
</xsl:template>

<!-- INSTANTIATION: Date - prolog/critdates/created -->
<xsl:template match="*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/created ')]" mode="gen-metadata">
  <meta name="DC.Date.Created" content="{@date}"/>
  
</xsl:template>

<!-- prolog/critdates/revised/@modified -->
<xsl:template match="*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/revised ')]/@modified" mode="gen-metadata">
  <meta name="DC.Date.Modified" content="{.}"/>
  
</xsl:template>

<!-- prolog/critdates/revised/@golive -->
<xsl:template match="*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/revised ')]/@golive" mode="gen-metadata">
  <meta name="DC.Date.Issued" content="{.}"/>
  
  <meta name="DC.Date.Available" content="{.}"/>
  
</xsl:template>

<!-- prolog/critdates/revised/@expiry -->
<xsl:template match="*[contains(@class,' topic/critdates ')]/*[contains(@class,' topic/revised ')]/@expiry" mode="gen-metadata">
  <meta name="DC.Date.Expiry" content="{.}"/>
  
</xsl:template>

<xsl:template match="*[contains(@class,' topic/othermeta ')]" mode="gen-metadata">
  <meta name="{@name}" content="{@content}"/>
  
</xsl:template>

<xsl:template match="*" mode="gen-format-metadata">
  <meta name="DC.Format" content="XHTML"/>
  
</xsl:template>

<xsl:template match="@id" mode="gen-metadata">
  <meta name="DC.Identifier" content="{.}"/>
  
</xsl:template>

<xsl:template match="@xml:lang" mode="gen-metadata">
  <meta name="DC.Language" content="{.}"/>
  
</xsl:template>

</xsl:stylesheet>
