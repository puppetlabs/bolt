<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2006 IBM Corporation

See the accompanying LICENSE file for applicable license.
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0">
  
  <xsl:import href="plugin:org.dita.base:xsl/common/dita-utilities.xsl"/>
  <xsl:import href="plugin:org.dita.base:xsl/common/output-message.xsl"/>
  
  <xsl:param name="version">0.0.0</xsl:param>
  <xsl:param name="provider">DITA</xsl:param>
  <xsl:param name="TOCROOT">toc</xsl:param>
  <xsl:param name="osgi.symbolic.name" select="''"/>
  
  <xsl:param name="fragment.country" select="''"/>
  <xsl:param name="fragment.lang"  select="''"/>  
  <xsl:param name="dita.plugin.output" />
  <xsl:param name="plugin"/>
  
  <xsl:variable name="newline">
<xsl:text>&#10;</xsl:text></xsl:variable>

  
  <!-- Define the error message prefix identifier -->
  <!-- Deprecated since 2.3 -->
  <xsl:variable name="msgprefix">DOTX</xsl:variable>
  
  <xsl:template match="/"> 
    <xsl:call-template name="eclipse.plugin.init"/>    
  </xsl:template>
  
  <xsl:template name="eclipse.plugin.init">
    <xsl:if test="$dita.plugin.output !=''">
      <xsl:choose>
        <xsl:when test="$dita.plugin.output ='dita.eclipse.fragment'">
          <xsl:apply-templates mode="eclipse.fragment"/> 
        </xsl:when>
        <xsl:when test="$dita.plugin.output ='dita.eclipse.properties'">
          <xsl:apply-templates mode="eclipse.properties"/>
        </xsl:when>
        <xsl:when test="$dita.plugin.output ='dita.eclipse.manifest'">
          <xsl:apply-templates mode="eclipse.manifest"/>
        </xsl:when>
        <xsl:when test="$dita.plugin.output ='dita.eclipse.plugin'">
          <xsl:apply-templates mode="eclipse.plugin"/>
        </xsl:when>
        <!--  XSLT 2.0 param value used to generate all eclipse plugin related files.-->
        <xsl:when test="$dita.plugin.output ='dita.eclipse.all'">
          
        </xsl:when>
        <!-- Produce the content for the plugin.xml file -->
        <xsl:otherwise>
          <xsl:apply-templates />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
    
    <xsl:if test="$dita.plugin.output =''">
      <xsl:apply-templates />
    </xsl:if>
    
  </xsl:template>
  
  <!-- Depracated Template: Use the template with mode="eclipse.plugin" instead -->
  <xsl:template match="*[contains(@class, ' map/map ')]">
    <xsl:element name="plugin">
      <xsl:attribute name="name">
        <xsl:choose>
          <xsl:when test="*[contains(@class, ' topic/title ')]">
            <xsl:apply-templates select="*[contains(@class,' topic/title ')]" mode="text-only"/>
      </xsl:when>
          <xsl:when test="@title">
            <xsl:value-of select="@title"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>Sample Title</xsl:text>
          </xsl:otherwise>
        </xsl:choose>        
      </xsl:attribute>
      <xsl:attribute name="id">
        <xsl:choose>
          <xsl:when test="@id">
            <xsl:value-of select="@id"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>org.sample.help.doc</xsl:text>
            <xsl:call-template name="output-message">
              <xsl:with-param name="id" select="'DOTX050W'"/>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:attribute name="version">
        <xsl:value-of select="$version"/>
      </xsl:attribute>
      <xsl:attribute name="provider-name">
        <xsl:value-of select="$provider"/>
      </xsl:attribute>
      <xsl:element name="extension">
        <xsl:attribute name="point">
          <xsl:text>org.eclipse.help.toc</xsl:text>
        </xsl:attribute>
        <xsl:element name="toc">
          <xsl:attribute name="file">
            <xsl:value-of select="$TOCROOT"/>
            <xsl:text>.xml</xsl:text>
          </xsl:attribute>
          <xsl:attribute name="primary">
            <xsl:text>true</xsl:text>
          </xsl:attribute>
        </xsl:element>
      </xsl:element>
      <xsl:element name="extension">
        <xsl:attribute name="point">
          <xsl:text>org.eclipse.help.index</xsl:text>
        </xsl:attribute>
        <xsl:element name="index">
          <xsl:attribute name="file">
            <xsl:text>index.xml</xsl:text>
          </xsl:attribute>
        </xsl:element>
      </xsl:element>     
    </xsl:element>
  </xsl:template>
  
  <!--  The elipse.plugin mode teamplate is used to create a plugin.xml file. -->  
  <xsl:template match="*[contains(@class, ' map/map ')]" mode="eclipse.plugin">
    <xsl:element name="plugin">
     <!-- <xsl:attribute name="name">
        <xsl:choose>
          <xsl:when test="*[contains(@class, ' topic/title ')]">
            <xsl:value-of select="*[contains(@class, ' topic/title ')]"/>
          </xsl:when>
          <xsl:when test="@title">
            <xsl:value-of select="@title"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>Sample Title</xsl:text>
          </xsl:otherwise>
        </xsl:choose>        
      </xsl:attribute>
      <xsl:attribute name="id">
        <xsl:choose>
          <xsl:when test="@id">
            <xsl:value-of select="@id"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>org.sample.help.doc</xsl:text>
            <xsl:call-template name="output-message">
              <xsl:with-param name="id" select="'DOTX050W'"/>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:attribute name="version">
        <xsl:value-of select="$version"/>
      </xsl:attribute>
      <xsl:attribute name="provider-name">
        <xsl:value-of select="$provider"/>
      </xsl:attribute>-->
      <xsl:element name="extension">
        <xsl:attribute name="point">
          <xsl:text>org.eclipse.help.toc</xsl:text>
        </xsl:attribute>
        <xsl:element name="toc">
          <xsl:attribute name="file">
            <xsl:value-of select="$TOCROOT"/>
            <xsl:text>.xml</xsl:text>
          </xsl:attribute>
          <xsl:attribute name="primary">
            <xsl:text>true</xsl:text>
          </xsl:attribute>
        </xsl:element>
      </xsl:element>      
        <xsl:element name="extension">
        <xsl:attribute name="point">
          <xsl:text>org.eclipse.help.index</xsl:text>
        </xsl:attribute>
        <xsl:element name="index">
          <xsl:attribute name="file">
            <xsl:text>index.xml</xsl:text>
          </xsl:attribute>
        </xsl:element>
      </xsl:element> 
    </xsl:element>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' map/map ')]" mode="eclipse.fragment">
    <xsl:element name="fragment">
      <xsl:choose>
        <xsl:when test="@title"><xsl:attribute name="name">%name</xsl:attribute>
        </xsl:when>
        <xsl:when test="*[contains(@class, ' topic/title ')]">
            <xsl:apply-templates select="*[contains(@class,' topic/title ')]" mode="text-only"/>
        </xsl:when>
        <xsl:otherwise><xsl:attribute name="name">Sample Title</xsl:attribute>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:choose>
        <xsl:when test="$osgi.symbolic.name!=''">
        <xsl:attribute name="plugin-id"><xsl:value-of select="$osgi.symbolic.name"/></xsl:attribute>
          <xsl:if test="$fragment.lang!=''">
            <xsl:choose>
              <xsl:when test="$fragment.country!=''">
                <xsl:attribute name="id"><xsl:value-of select="$osgi.symbolic.name"/>.<xsl:value-of select="$fragment.lang"/>.<xsl:value-of select="$fragment.country"/></xsl:attribute>
              </xsl:when>
              <xsl:otherwise>
                <xsl:attribute name="id"><xsl:value-of select="$osgi.symbolic.name"/>.<xsl:value-of select="$fragment.lang"/></xsl:attribute>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:if>
        
        </xsl:when>
        <xsl:when test="@id">
          <xsl:attribute name="plugin-id"><xsl:value-of select="@id"/></xsl:attribute>
          <xsl:if test="$fragment.lang!=''">
            <xsl:choose>
              <xsl:when test="$fragment.country!=''">
                <xsl:attribute name="id"><xsl:value-of select="@id"/>.<xsl:value-of select="$fragment.lang"/>.<xsl:value-of select="$fragment.country"/></xsl:attribute>
              </xsl:when>
              <xsl:otherwise>
                <xsl:attribute name="id"><xsl:value-of select="@id"/>.<xsl:value-of select="$fragment.lang"/></xsl:attribute>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:if>
        </xsl:when>
        <xsl:otherwise>
          <xsl:attribute name="plugin-id">org.sample.help.doc</xsl:attribute>
          <xsl:attribute name="id">org.sample.help.doc.sample.lang</xsl:attribute>
          <xsl:call-template name="output-message">
            <xsl:with-param name="id" select="'DOTX050W'"/>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
      
      <xsl:attribute name="plugin-version">
        <xsl:value-of select="$version"/>
      </xsl:attribute>
      <xsl:attribute name="version">
        <xsl:value-of select="$version"/>
      </xsl:attribute>
      
      <xsl:attribute name="provider-name">
        <!--            <xsl:value-of select="$provider"/> -->
        <xsl:text>%providerName</xsl:text>
      </xsl:attribute>
      <!-- <xsl:apply-templates/> -->
    </xsl:element>
  </xsl:template>
  
  
  <xsl:template match="*[contains(@class, ' map/map ')]" mode="eclipse.properties">
    
    <xsl:text># NLS_MESSAGEFORMAT_NONE</xsl:text><xsl:value-of select="$newline"/>
    <xsl:text># NLS_ENCODING=UTF-8</xsl:text><xsl:value-of select="$newline"/>
    <!--<xsl:value-of select="$newline"/>-->
    <xsl:choose>
      <xsl:when test="@title">
        <xsl:text>name=</xsl:text><xsl:value-of select="@title"/>
      </xsl:when>
      <xsl:when test="*[contains(@class, ' topic/title ')]">
        <xsl:text>name=</xsl:text><xsl:apply-templates select="*[contains(@class,' topic/title ')]" mode="text-only"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>name=Sample Title</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:value-of select="$newline"/>
    <xsl:text>providerName=</xsl:text><xsl:value-of select="$provider"/>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' map/map ')]" mode="eclipse.manifest">
    
    <xsl:text>Bundle-Version: </xsl:text><xsl:value-of select="$version"/><xsl:value-of select="$newline"/>
    <xsl:text>Manifest-Version: 1.0</xsl:text><xsl:value-of select="$newline"/>
    <xsl:text>Bundle-ManifestVersion: 2</xsl:text><xsl:value-of select="$newline"/>
    <xsl:text>Bundle-Localization: plugin</xsl:text><xsl:value-of select="$newline"/>
    <xsl:text>Bundle-Name: %name</xsl:text><xsl:value-of select="$newline"/>
    <xsl:text>Bundle-Vendor: %providerName</xsl:text><xsl:value-of select="$newline"/>
    
    <xsl:choose>
      <xsl:when test="$plugin='true'">
        <xsl:text>Eclipse-LazyStart: true</xsl:text><xsl:value-of select="$newline"/>
        <xsl:choose>
          <xsl:when test="$osgi.symbolic.name!=''">
          <xsl:text>Bundle-SymbolicName: </xsl:text><xsl:value-of select="$osgi.symbolic.name"/>;<xsl:text> singleton:=true</xsl:text><xsl:value-of select="$newline"/>
          </xsl:when>
          <xsl:when test="@id">
            <xsl:text>Bundle-SymbolicName: </xsl:text><xsl:value-of select="@id"/>;<xsl:text> singleton:=true</xsl:text><xsl:value-of select="$newline"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>Bundle-SymbolicName: org.sample.help.doc; singleton:=true</xsl:text><xsl:value-of select="$newline"/>
            <xsl:call-template name="output-message">
              <xsl:with-param name="id" select="'DOTX050W'"/>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose> 
      </xsl:when>
      <xsl:otherwise>
        <xsl:choose>
          <xsl:when test="@id">                        
            <xsl:if test="$fragment.lang!=''">
              <xsl:text>Fragment-Host: </xsl:text><xsl:value-of select="@id"/>;
              <xsl:text>Bundle-SymbolicName: </xsl:text>
              <xsl:choose>
                <xsl:when test="$fragment.country!=''">
                  <xsl:value-of select="@id"/>.<xsl:value-of select="$fragment.lang"/>.<xsl:value-of select="$fragment.country"/>;<xsl:text/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="@id"/>.<xsl:value-of select="$fragment.lang"/>;<xsl:text/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:if> 
            <xsl:if test="$fragment.lang=''">
              <xsl:text>Bundle-SymbolicName: </xsl:text><xsl:value-of select="@id"/><xsl:value-of select="$newline"/>
            </xsl:if>
          </xsl:when>
          <xsl:otherwise>
            
            <xsl:text>Bundle-SymbolicName: org.sample.help.doc.</xsl:text>
            <xsl:choose>
              <xsl:when test="$fragment.lang!=''">
                <xsl:choose>
                  <xsl:when test="$fragment.country!=''">
                    <xsl:value-of select="$fragment.lang"/>.<xsl:value-of select="$fragment.country"/>;
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="$fragment.lang"/>;
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:when>
              <!-- We shouldn' t be getting here, but just in case -->
              <xsl:otherwise>
                <xsl:text>lang; </xsl:text>
              </xsl:otherwise>
            </xsl:choose>
            <xsl:value-of select="$newline"/>
            <xsl:text>Fragment-Host: org.sample.help.doc;</xsl:text><xsl:value-of select="$newline"/>
            <xsl:call-template name="output-message">
              <xsl:with-param name="id" select="'DOTX050W'"/>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>                 
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
</xsl:stylesheet>
