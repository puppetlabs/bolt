<?xml version="1.0" encoding="UTF-8"?>
<!--
This file is part of the DITA Open Toolkit project.

Copyright 2016 Jarno Elovirta

See the accompanying LICENSE file for applicable license.
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:dita2html="http://dita-ot.sourceforge.net/ns/200801/dita2html"
                version="2.0"
                exclude-result-prefixes="xs dita2html">
  
  <xsl:param name="GENERATE-TASK-LABELS" select="'NO'"/>

  <xsl:template match="*[contains(@class, ' task/cmd ')]" name="task.cmd">
    <para>
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates/>
    </para>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' task/info ')] |
                       *[contains(@class, ' task/stepresult ')] |
                       *[contains(@class, ' task/stepxmp ')] |
                       *[contains(@class, ' task/tutorialinfo ')] |
                       *[contains(@class, ' task/steptroubleshooting ')]">
    <div>
      <xsl:call-template name="commonattributes"/>
      <xsl:call-template name="setidaname"/>
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' task/steps ')]" name="task.steps">
    <xsl:apply-templates select="." mode="generate-task-label">
      <xsl:with-param name="use-label">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'task_procedure'"/>
        </xsl:call-template>
      </xsl:with-param>
    </xsl:apply-templates>
    <xsl:next-match/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' task/steps-unordered ')]" name="task.steps-unordered">
    <xsl:apply-templates select="." mode="generate-task-label">
      <xsl:with-param name="use-label">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'task_procedure_unordered'"/>
        </xsl:call-template>
      </xsl:with-param>
    </xsl:apply-templates>
    <xsl:next-match/>
  </xsl:template>

  <xsl:template match="*[contains(@class,' task/prereq ')]" mode="dita2html:section-heading">
    <xsl:apply-templates select="." mode="generate-task-label">
      <xsl:with-param name="use-label">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'task_prereq'"/>
        </xsl:call-template>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/context ')]" mode="dita2html:section-heading">
    <xsl:apply-templates select="." mode="generate-task-label">
      <xsl:with-param name="use-label">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'task_context'"/>
        </xsl:call-template>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
      
  <xsl:template match="*[contains(@class,' task/result ')]" mode="dita2html:section-heading">
    <xsl:apply-templates select="." mode="generate-task-label">
      <xsl:with-param name="use-label">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'task_results'"/>
        </xsl:call-template>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="*[contains(@class,' task/postreq ')]" mode="dita2html:section-heading">
    <xsl:apply-templates select="." mode="generate-task-label">
      <xsl:with-param name="use-label">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'task_postreq'"/>
        </xsl:call-template>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  
  <!--<xsl:template match="*[contains(@class,' task/taskbody ')]/*[contains(@class,' topic/example ')]">-->
    <!--<section>-->
      <!--<xsl:call-template name="commonattributes"/>-->
      <!--<xsl:call-template name="gen-toc-id"/>-->
      <!--<xsl:call-template name="setidaname"/>-->
      <!--<xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-startprop ')]" mode="out-of-line"/>-->
      <!--<xsl:apply-templates select="." mode="dita2html:section-heading"/>-->
      <!--<xsl:apply-templates select="node() except *[contains(@class, ' topic/title ')]"/>-->
      <!--<xsl:apply-templates select="*[contains(@class, ' ditaot-d/ditaval-endprop ')]" mode="out-of-line"/>-->
    <!--</section>-->
  <!--</xsl:template>-->
  
  <xsl:template match="*[contains(@class,' task/taskbody ')]/*[contains(@class,' topic/example ')][not(*[contains(@class,' topic/title ')])]" mode="dita2html:section-heading">
    <xsl:apply-templates select="." mode="generate-task-label">
      <xsl:with-param name="use-label">
        <xsl:call-template name="getVariable">
          <xsl:with-param name="id" select="'task_example'"/>
        </xsl:call-template>
      </xsl:with-param>
    </xsl:apply-templates>
  </xsl:template>
  
  <xsl:template match="*" mode="generate-task-label">
    <xsl:param name="use-label"/>
    <xsl:param name="headLevel" as="xs:integer">
      <xsl:variable name="headCount" select="count(ancestor::*[contains(@class, ' topic/topic ')]) + 1"/>
      <xsl:choose>
        <xsl:when test="$headCount > 6">6</xsl:when>
        <xsl:otherwise><xsl:value-of select="$headCount"/></xsl:otherwise>
      </xsl:choose>
    </xsl:param>
    <xsl:if test="$GENERATE-TASK-LABELS = 'YES'">
      <header level="{$headLevel}">
        <xsl:call-template name="commonattributes">
          <xsl:with-param name="default-output-class" select="name(..)"/>
        </xsl:call-template>
        <xsl:value-of select="$use-label"/>
      </header>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
