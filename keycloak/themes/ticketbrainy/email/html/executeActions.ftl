<#outputformat "plainText">
<#assign requiredActionsText><#if requiredActions??><#list requiredActions><#items as reqActionItem>${msg("requiredAction.${reqActionItem}")}<#sep>, </#sep></#items></#list></#if></#assign>
</#outputformat>

<#import "template.ftl" as layout>
<@layout.emailLayout>
<h3 style="margin:24px 0 8px 0;color:#0f172a;">${msg("tbStep1Title")}</h3>
${kcSanitize(msg("executeActionsBodyHtml",link, linkExpiration, realmName, requiredActionsText, linkExpirationFormatter(linkExpiration)))?no_esc}

<h3 style="margin:32px 0 8px 0;color:#0f172a;">${msg("tbStep2Title")}</h3>
<p>${msg("tbStep2Body")}</p>
<p><a href="__TB_PORTAL_URL__" style="display:inline-block;padding:10px 18px;background:#2563eb;color:#fff;text-decoration:none;border-radius:6px;font-weight:600;">${msg("tbStep2Cta")}</a></p>
<p style="font-size:12px;color:#64748b;margin-top:8px;">__TB_PORTAL_URL__</p>
</@layout.emailLayout>
